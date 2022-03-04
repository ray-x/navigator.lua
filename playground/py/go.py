from random import shuffle
a = list(range(5))

def go(beg, c, b):
    if beg >= len(a):
        print(a )
    for i in range(beg, len(a)):
        a[beg], a[i] = a[i], a[beg]
        go(beg + 1)
        a[beg], a[i] = a[i], a[beg]
    print(a, b)

go(0, 1, 4)
shuffle([1, 2,3 ])
