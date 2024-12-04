# Rough Python Notes
- Finction definition

def addition (n1 , n2) ----> (Read Values it can be anything when we call the function inside this bracket)
    add = n1 + n2
    return add

print (addition(5,10))  ---> Call the funtion with values inside ()

- Function writing logic
    - Take input
    - Perform operation
    - Return output
(refrain from hardcoding the values in function)

- Any python file inside the working directory folder can be used as module considering it has a useful function :)

- Packages or Libraries is collection of Modules and Modules is colletion of function

- By default argumensts are read as string .... we need to convert them to integer if thats the need of function or code.

- INPUT Methods :
- cmd line args or env_vars are types of arguments we can use in code.
        |             |
  for normal args    for sensitive info (password, keys etc)

- Input is also one of the arguments we can use in code to read.

- sys -> to read args like sys.arg[]
- os -> to read env_vars like os.getenv("env variable name")

- List => to store the values which needs to be changed , heterogenus as all types of elements can be stored.
- Tuple => to store a list which dont need to be chnage -> eg:- passwords, adminusers, admin buckets etc.
- Object index starts from 0.

- How to write a for loop
        for x in range
            |      |
          variable sequence it can be list or tuple or range

- When to us while? 
    - when we are not aware of number of executions till the condition is met.
    - eg:-> print deleted until all the files in /tmp are deleted

- Loop manupulation statement
    - break -> to break the for loop if the condition passes or fails
    - continue -> to continue the for or while loop if the condition passes skipping the matched value.

- Dictonary -> { "key" : "value" } it can be used in list to create a list of dictonaries
        - to retrive the value we can use dict_list[0]["key"] if its from list
        - if just single dictonary we can use value = name_dict.get("key") or name_dict["key"]
- List -> []
- Tupe -> ()
- Set -> {} (This has intersection Uninon and Difference operations)

# Data Structures
- How the data is structured in application or python
    - List
    - Set
    - Tuple
    - Dictonaries

# Data Types
- What is the type of data 
    - String
    - Integer
    - Float
    - Decimal
    - Boolean (true or false)
