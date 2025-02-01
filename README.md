# maclaurinSeriesCalc
In this project we're making a maclaurin series claculator chip in verilog language

### pseudo code for exp in C
term = 1
exp = 1
for (i = 1, i < n, i++) {
term = term * x;
term = term * 1/i;
exp = term + exp
}

### pseudo code for sin in C
term = x        
sin = x         
x_squared = x * x   
current_power = x   
for (i = 3; i <= n; i += 2) {  // Loop through odd numbers 3,5,7,...
    // Update power of x (multiply by x² each time to get x³, x⁵, x⁷...)
    current_power = current_power * x_squared
    
    // factorial 
    term = current_power
    term = term / (i * (i-1))  // Divide by i! (i * (i-1) * (i-2)...)
    
    // Alternate between subtraction and addition (+ for i=3,7,11...; - for i=5,9,13...)
    if (i % 4 == 3)
        sin = sin + term
    else
        sin = sin - term
}
