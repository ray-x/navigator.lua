import math
import numpy as np
import os

class Dog:
    def __init__(self, name):
        self.name = name
        self.tricks = []    # creates a new empty list for each dog

    def add_trick(self, trick):
        self.tricks.append(trick)


d = Dog('Fido')
d.add_trick('roll over')
print(d.tricks)

def test_func():
    k = [1, 2, 3]
    sum = 0
    for i in range(k, 1, 2):
        sum += 1
        print(sum)

def greet(greeting, name):
    """
    This function greets to
    the person passed in as
    a parameter
    """
    print(greeting + name + ". Good morning!")


# def greet(greeting, name, msg1, msg2):
#     """
#     This function greets to
#     the person passed in as
#     a parameter
#     """
#     print(greeting + name + ". Good morning!")


greet("a", "b")


def greet2():
    print("whatever")


def greet3(name):
    greet2()
    greet("hey", "dude", "", "")
    print("whatever" + name)

def greet3():
    pass


greet2()

greet("name", "name")

greet3("name")
greet3("")

greet("1", "2")


def greeting(greet: int, *, g):
    """
    This function greets to
    the person passed in as
    a parameter
    """
    print(greet + g + ". Good morning!")


np.empty(1, order="F")
np.empty(1, order="F")
