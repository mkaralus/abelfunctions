import unittest

from sympy import Poly, I, Rational
from sympy.abc import x,y,Z,T

from abelfunctions.puiseux import (
    _coefficient, _new_polynomial, polygon, puiseux)


# === test curves ===
# Example curves are from "Computing with Plane Algebraic Curves and Riemann 
# Surfaces" by Deconinck and Patterson, Lecture Notes in Mathematics, 2011
f1 = (x**2 - x + 1)*y**2 - 2*x**2*y + x**4                   # p. 71
f2 = y**3 + 2*x**3*y - x**7                                  # p. 73
f3 = (y**2-x**2)*(x-1)*(2*x-3) - 4*(x**2+y**2-2*x)**2        # p. 75
f4 = y**2 + x**3 - x**2                                      # p. 82
f5 = (x**2 + y**2)**3 + 3*x**2*y - y**3                      # p. 84
f6 = y**4 - y**2*x + x**2                                    # p. 85
f7 = y**3 - (x**3 + y)**2 + 1                                # p. 85

# example singular curves:
f8 = x**2*y**6 + 2*x**3*y**5 - 1
f9 = 2*x**7*y + 2*x**7 + y**3 + 3*y**2 + 3*y
f10= (x**3)*y**4 + 4*x**2*y**2 + 2*x**3*y - 1


class TestPuiseux(unittest.TestCase):

    def setUp(self):
        pass

    def test_coefficient(self):
        p1 = Poly(f1,x,y)
        p2 = Poly(f2,x,y)
        p3 = Poly(f3,x,y)
        p4 = Poly(f4,x,y)
        p5 = Poly(f5,x,y)
        p6 = Poly(f6,x,y)
        p7 = Poly(f7,x,y)
        p8 = Poly(f8,x,y)
        self.assertEqual(_coefficient(p1),
                         {(0,4):1, (1,2):-2, (2,0):1, (2,1):-1, (2,2): 1})
        self.assertEqual(_coefficient(p2),
                         {(0,7):-1, (1,3):2, (3,0):1})
        self.assertEqual(_coefficient(p7),
                         {(0,0):1, (0,6):-1, (1,3):-2, (2,0):-1, (3,0):1})
        self.assertEqual(_coefficient(p8),
                         {(0,0):-1, (5,3):2, (6,2):1})

    
    def test_puiseux(self):
        self.assertEqual(puiseux(f1,x,y,0,4,parametric=T),
            [(T**2, T**7/2 + T**6 + T**5 + T**4)])

        self.assertEqual(puiseux(f2,x,y,0,4,parametric=T),
            [(T,-3*T**19/256 + 3*T**14/128 - T**9/16 + T**4/2), 
             (-T**2/2,-T**18/16384 + 3*T**13/4096 - T**8/64 - T**3/2)])

        half = Rational(1,2)
        self.assertEqual(puiseux(f3,x,y,0,0,parametric=T),
            [(-57**half*T/19, 136*57**half*T**2/1083 + T), 
             (57**half*T/19, -136*57**half*T**2/1083 + T), 
             (T, -11*3**half*T/12 - 3**half/2), 
             (T, 11*3**half*T/12 + 3**half/2)])

        self.assertEqual(puiseux(f4,x,y,0,4,parametric=T),
                         [(-T, T**4/16 - T**3/8 + T**2/2 + T),
                          (T, -T**4/16 - T**3/8 - T**2/2 + T)])
