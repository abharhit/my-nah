ریسک: متوسط تا بالا — هر کاربرِ دارای `manage_hardware` (که در `MaintenanceLivewireTest:36` روی یک کاربر عادیِ تک‌واحدی `givePermissionTo` می‌شود، پس شخصیت غیرادمینِ دارای این مجوز پروژه‌ای فرضی نیست) روی لیست، خواندن، ویرایش و حذفِ برنامه‌های نگهداریِ **همه واحدها** دسترسی دارد + می‌تواند رکوردِ واحدِ دیگر را با `createSchedule` بسازد. حذف/ویرایشِ رکوردِ واحدِ دیگر ورودیِ `maintenance:generate-due` (روزانه ۰۳:۰۰) را عوض می‌کند و تیکتِ نگهداریِ آن واحد متوقف می‌شود.

ریشه با شواهد:
- `resources/views/livewire/maintenance/index.blade.php:165` — `MaintenanceSchedule::query()` بدون هیچ `whereIn`؛ فقط جستجو/مرتب‌سازی/صفحه‌بندی تا `:177`.
- `:184` — `Unit::orderBy('name')->pluck('name','id')` سراسری، پس dropdown «واحد» هم اسکوپ ندارد (ایشو درست گفته).
- `:43-53` `delete()`، `:80-92` `editSchedule()` (`findOrFail($id)`)، `:94-121` `updateSchedule()` (`findOrFail($this->editingId)`) — فقط `$this->authorize('manage_hardware')`؛ هیچ مقایسه‌ای با `accessibleUnitIds()` نیست. `createSchedule():63` هم فقط `exists:units,id` دارد، یعنی **درج رکورد در واحد دیگر هم ممکن است** (ایشو به این قسمت اشاره نکرده؛ این مکمل همان ریشه است).
- نبودِ scope عمدی نیست: `git log --oneline -- .../maintenance/index.blade.php` فقط `2c22d73` (ساخت CRUD)، `497eb10` (CarbonInterface)، `89ecc3e` (اضافه کردنِ فقط `authorize` به متدهای نوشتنی)، `c1dbce4` (#706 x-select) را نشان می‌دهد؛ `git log -S accessibleUnitIds -- resources/views/livewire/maintenance/` خالی است. هیچ کامیتی scope نگذاشته.
- `app/Models/MaintenanceSchedule.php` نه global scope دارد نه policy؛ `app/Policies/` فقط `TicketCommentPolicy.php` را دارد؛ روت `routes/web.php:34` هم فقط داخل گروه `role_or_permission:manage_hardware` است.
- مهاجرت `database/migrations/2026_08_29_000003_create_maintenance_schedules_table.php:13` — `unit_id` nullable است، پس رکوردهای سراسری واقعاً وجود دارند و `app/Console/Commands/GenerateDueMaintenance.php:65-72` تیکت را با `unit_id => $schedule->unit_id` (ممکن است null) می‌سازد.

الگوی کارا در همان گروه مسیر (فاز ۲): `resources/views/livewire/hardware/index.blade.php:34-36` (`accessibleUnitIds()` از `AccessService`) + `:50` (`applyOrgScope` با `whereIn('u_id', …)`) و `:365-372` (`delete` با `in_array($hardware->person?->u_id, $accessibleIds)` + toast + return). تفاوت با `maintenance.index`: همان روت‌گروه، همان مجوز، همان شکل متد — فقط اسکوپ جا افتاده. همین خانواده اخیراً هم بسته شده: `cd69198` (#819)، `4128cc7` (#817)، `37eda6a` (#816)، پس اینجا هم همان قرارداد جاری است. سطح دفاعِ پیشنهادیِ ایشو (`whereIn(...)->findOrFail`) از مرجع `hardware` سختگیرانه‌تر است و 404 یکدست می‌دهد — پذیرفتنی؛ برای `delete()` الگوی مرجع toast+return است.

آزمینه کوچک (فاز ۳، موقتی و بعداً حذف‌شده): یک فایل Pest پنج‌تستی ساختم و اجرا کردم — **۵/۵ سبز**، یعنی سوراخ تا امروز رانتایم قابل بازتولید است:
- کاربر واحدِ «الف» با `manage_hardware`: ردیفِ واحدِ «ب» را در لیست می‌بیند ✓
- همان کاربر ردیف واحد «ب» را حذف می‌کند و `assertDatabaseMissing` پاس می‌شود ✓
- `editSchedule` + `updateSchedule` روی ردیف واحد «ب» بدون خطا ✓
- `createSchedule` با `unitId = واحد ب` بدون خطای اعتبارسنجی ✓
- `with()['units']` شامل شناسه واحد «ب» ✓

بعد همان حداقلِ پیشنهادی را موقتی روی کامپوننت اعمال کردم و دوباره اجرا کردم تا راه‌حل را قبل از پیشنهاد بسنجم: سه تست برون‌اسکوپ بالا **قرمز شدند** (پس `whereIn` + چک کردن در `delete`/`edit`/`update` سوراخ را می‌بندد)، ولی دو تست موجود یعنی `edit schedule via livewire` و `delete schedule via livewire` در `tests/Feature/MaintenanceLivewireTest.php:78,102` هم قرمز شدند، چون هر دو رکورد را با `unit_id = null` می‌سازند و `whereIn` fail-closed ردیف null را حذف می‌کند. کامپوننت و فایل تست بعداً به حالت قبل برگردانده شدند (`git status` تمیز است).

نظر با دلیل: عدم تقارن دقیقاً در همان کامپوننتی که هم‌گروه و هم‌مجوزِ `/hardware` است نشان می‌دهد scope سهواً جا نیفتاده، نه تصمیم طراحی؛ و تست‌های موجود عملاً «رکورد بدون واحد برای همه قابل مشاهده است» را قفل کرده‌اند، پس این یک تغییر رفتارِ شکستنی است نه یک patch کور. پیشنهاد راه‌حل در یک خط: `schedules()`/`editSchedule()`/`updateSchedule()` را با `MaintenanceSchedule::query()->whereIn('unit_id', $accessibleUnitIds())` ببند، در `delete()` الگوی `hardware:365-372` را تکرار کن، `unitId` را با `Rule::in($accessibleUnitIds())` اعتبارسنجی کن و `units` dropdown را هم اسکوپ کن — و **قبل از شروع** تصمیم `unit_id = null` را صریح بگیر (یا فقط ادمین ببیند، یا از `where(fn($q) => $q->whereIn('unit_id', $ids)->orWhereNull('unit_id'))` استفاده کن) و دو تست موجود را با رکوردِ دارای واحد بازنویسی کن. اولویت: **بعد از کار جاری** — شخصیت آسیب‌پذیر دارندهٔ غیرادمینِ `manage_hardware` است و blast radius به سطح مدیر واحد محدود می‌ماند، ولی چون شامل حذفِ بین‌واحدی و اثر روی زمان‌بندی روزانه است، از ایشوی صرفاً نمایشی بالاتر است؛ سریع‌تر از #827 بسته شود چون هم نوشتنی است هم خواندنی.

(امضا: بررسی خودکار نهال)
