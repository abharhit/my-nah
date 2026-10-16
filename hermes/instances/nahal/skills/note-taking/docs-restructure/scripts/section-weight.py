#!/usr/bin/env python3
"""Profile a markdown doc: bytes and lines per ##/### section, to decide what to split."""
import re
import sys

path = sys.argv[1]
lines = open(path).read().splitlines()
secs = [(re.sub(r'^#+ ', '', l).strip(), i) for i, l in enumerate(lines) if re.match(r'^#{2,3} ', l)]
secs.append(('__END__', len(lines)))
total = 0
for (name, i), (_, j) in zip(secs, secs[1:]):
    body = '\n'.join(lines[i:j])
    b = len(body.encode())
    total += b
    print(f'{b:>7} B {j - i:>4} ln  {name[:70]}')
print(f'{total:>7} B total')
