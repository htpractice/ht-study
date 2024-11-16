import sys

'''Task 2: Comparison Operators
Compare the values of a and b using the following comparison operators: <, >, <=, >=, ==, and !=.
Print the results of each comparison.'''

'''Use elif when you want only one result to be printed based on the first true condition.
Use if statements (without elif) when you want all applicable comparisons to be printed.'''

def comparison(a,b):
    if a == b:
        print ("a equal to b")

    if a < b:
        print ("a is less than b")

    if a > b:
        print ("a is greater than b")

    if a >= b:
        print ("a is greater than equal to b")

    if a <= b:
        print ("a is less than equal to b")

    if a != b:
        print ("a not  equal to b")

a = float(sys.argv[1])
b = float(sys.argv[2])

comparison(a,b)