mclaren not taylor

### Exp pseudo code: 
```c
term = 1;
exp = 1;
for (i=1; i<n; i++) {
    term = term * xin;
    term = term * 1/i!;
    exp = exp + term;
}
```

### Sin pseudo code: 
```c
term = xin;
sin = xin;
for (i=1; i<n; i++) {
    term = term * xin;
    term = term * xin;
    term = term * 1/i!;
    if (isOdd) {
        sin = sin - term;
    } else {
        sin = sin + term
    }
}
```
Iteration 0 (Initialization):
    tReg: x
    sReg: x

Iteration 1:
    tReg: (x^3) / 3! = (x^3) / 6
    sReg: x - (x^3) / 6

Iteration 2:
    tReg: (x^5) / 5! = (x^5) / 120
    sReg: x - (x^3) / 6 + (x^5) / 120

Iteration 3:
    tReg: (x^7) / 7! = (x^7) / 5040
    sReg: x - (x^3) / 6 + (x^5) / 120 - (x^7) / 5040

### ln(x+1) pseudo code: 
```c
term = 1;
ln = xin;
for (i=1; i<n; i++) {
    term = term * xin;
    term = term * 1/i;
    if (isOdd) {
        ln = ln - term;
    } else {
        ln = ln + term
    }
}
```


### Cos pseudo code: 
```c
term = 1;
cos = 1;
for (i=1; i<n; i++) {
    term = term * xin;
    term = term * xin;
    term = term * 1/i!;
    if (isOdd) {
        cos = cos - term;
    } else {
        cos = cos + term
    }
}
```
Iteration 0:
    tReg: 1
    cos: 1

Iteration 1:
    tReg: (xin^2) / 2! = (xin^2) / 2
    cos: 1 - (xin^2) / 2

Iteration 2:
    tReg: (xin^4) / 4! = (xin^4) / 24
    cos: 1 - (xin^2) / 2 + (xin^4) / 24

Iteration 3:
    tReg: (xin^6) / 6! = (xin^6) / 720
    cos: 1 - (xin^2) / 2 + (xin^4) / 24 - (xin^6) / 720

mclaren not taylor
