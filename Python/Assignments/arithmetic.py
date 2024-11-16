import sys

'''Task 1: Arithmetic Operators
Create two variables a and b with numeric values.
Calculate the sum, difference, product, and quotient of a and b.
Print the results.'''

def sum(a, b):
    s = a + b
    print (s)

def diff(a, b):
    d = a - b
    print (d)

def pro(a,b):
    pro = a * b
    print (pro)

def quo(a,b):
    quo = a / b
    print (f'{quo}')

    

a = float(sys.argv[1])
operation = sys.argv[2]
b = float(sys.argv[3])

if operation == "+":
    sum(a,b)

elif operation == "-":
    diff(a,b)

elif operation == "x":
    pro(a,b)

elif operation == "/":
    quo(a,b)

else:
    print("operaton needed")
