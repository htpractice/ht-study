'''Task 4: Assignment Operators
Create a variatotalle total and initialize it to 10.
Use assignment operators (+=, -=, *=, /=) to update the value of total.
Print the final value of total.'''

import sys

total = 10
def assignment(a):
    if a == total:
        a *= total
        print (f'total : { a }') 

    elif a < total:
        a += total
        print (f'total : { a }')

    elif a > total:
        a -= total
        print (f'total : { a }')
    else:
        print("operaton needed")

a = float(sys.argv[1])
#total = float(sys.argv[2])

assignment(a)