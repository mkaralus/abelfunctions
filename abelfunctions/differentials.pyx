"""
Differentials

This module contains functions for computing a basis of holomorphic
differentials of a Riemann surface given by a complex plan algebraic
curve `f \in C[x,y]`.

A differential `\omega = h(x,y)dx` defined on a Riemann surface `X` is
holomorphic on `X` if it is holomorphic at every point on `X`.
"""

cimport cython

import numpy
import sympy
import sympy.mpmath as mpmath
import matplotlib
import matplotlib.pyplot as plt

from .integralbasis import integral_basis
from .singularities import singularities, _transform, genus
from .utilities import cached_function
from .polynomials cimport MultivariatePolynomial

import pdb

def mnuk_conditions(f,u,v,b,P,c):
    """
    Determine the Mnuk conditions on the coefficients, c, of the general
    adjoint polynomial P at the point x=0.

    Note: it is assume t
    """
    numer, denom = b.as_numer_denom()

    # reduce b*P modulo f
    expr = numer.as_poly(v,u,*c) * P.as_poly(v,u,*c, domain='QQ[I]')
    q,r = sympy.polytools.reduced(expr,[sympy.poly(f,v,u,*c)])

    # divide by the largest power of x appearing in the denominator.
    # this is sufficient since we've shifted the curve and its
    # singularity to appear at
    try:
        mult = sympy.roots(denom.as_poly(u))[sympy.S(0)]
    except KeyError:
        mult = 0

    r = r.as_poly(u,v)
    coeffs = r.coeffs()
    monoms = r.monoms()
    conditions = [coeff for coeff,monom in zip(coeffs,monoms)
                  if monom[0] < mult]
    return conditions


def differentials(f,x,y):
    """
    Returns a basis of the holomorphic differentials defined on the
    Riemann surface `X: f(x,y) = 0`.

    Input:

    - f: a Sympy object describing a complex plane algebraic curve.

    - x,y: the independent and dependent variables, respectively.
    """
    # compute the "total degree" (Poly.total_degree doesn't give the
    # desired result). This is the largest monomial degree in the sum
    # of the degrees in both x and y.
    d = max(map(sum,f.as_poly(x,y).monoms()))
    n = sympy.degree(f,y)

    # define the "generalized" adjoint polynomial.
    c = sympy.symarray('c',(d-2,d-2)).tolist()
    P = sum( c[i][j] * x**i * y**j
             for i in range(d-2) for j in range(d-2)
             if i+j <= d-3)
    c = [cij for ci in c for cij in ci]

    # for each singular point [x:y:z] = [alpha:beta:gamma], map f onto
    # the "most convenient and appropriate" affine subspace, (u,v),
    # and center at u=0. determine the conditions on P
    S = singularities(f,x,y)
    conditions = []
    for singular_pt,(m,delta,r) in S:
        # recenter the curve and adjoint polynomial at the
        # singular point: find the affine plane u,v such that
        # the singularity occurs at u=0
        g,u,v,u0,v0      = _transform(f,x,y,singular_pt)
        g = g.subs(u,u+u0)
        Ptilde,u,v,u0,v0 = _transform(P,x,y,singular_pt)
        Ptilde = Ptilde.subs(u,u+u0)

        # compute the intergral basis at the recentered singular point
        # and determine the Mnuk conditions of the adjoint polynomial
        b = integral_basis(g,u,v)
        for bi in b:
            conditions_bi = mnuk_conditions(g,u,v,bi,Ptilde,c)
            conditions.extend(conditions_bi)

    # solve the system of equations and retreive the coefficents of the c_ij's
    # contained in the general solution
    sols = sympy.solve(conditions, c)
    P = P.subs(sols).as_poly(*c)
    differentials = [coeff for coeff in P.coeffs() if coeff != 0]

    # sanity check: the number of differentials matches the genus
    g = genus(f,x,y)
    if g != -1 and g != len(differentials):
        raise AssertionError("Number of differentials does not match genus.")

    differentials = [differential/sympy.diff(f,y)
                     for differential in differentials]
    return map(lambda omega: Differential(omega, x, y), differentials)



cdef class Differential:
    """A differential one-form which can be defined on a Riemann surface.

    Attributes
    ----------
    numer, denom : MultivariatePolynomial
        Fast multivariate polynomial objects representing the numerator
        and denominator of the differential.

    Methods
    -------
    eval(z1,z2)
        Fast evaluation of the differential.
    as_sympy()
        Returns the differential as a Sympy object.

    """
    def __cinit__(self, omega, x, y):
        """Instantiate a differential form from a sympy Expression.

        Arguments
        ---------
        omega : Sympy Expression
        x, y : Sympy Symbol
            The differential and its variables. Note in abelfunctions we
            consider `y` to be a function of `x`. (A degree d y-cover.)

        """
        numer, denom = omega.as_numer_denom()
        numer = numer.expand()
        denom = denom.expand()
        self.numer = MultivariatePolynomial(numer, x, y)
        self.denom = MultivariatePolynomial(denom, x, y)
        self._omega = omega

    def __repr__(self):
        return str(self._omega)

    cpdef complex eval(self, complex z1, complex z2):
        """Evaluate the differential at the complex point `(z1,z2)`.

        Arguments
        ---------
        z1,z2 : complex

        Returns
        -------
        complex
            Returns the value :math:`\omega(z1,z2)`.

        """
        return self.numer.eval(z1,z2) / self.denom.eval(z1,z2)

    def plot(self, gamma, N=256, grid=False, **kwds):
        """Plot the differential along the path `gamma`"""
        nsegs = len(gamma.segments)
        ppseg = N/nsegs

        fig = plt.figure()
        ax = fig.add_subplot(1,1,1)
        t = numpy.linspace(0,1,ppseg)
        for k in range(nsegs):
            segment = gamma.segments[k]
            xvals = [segment.get_x(ti) for ti in t]
            yvals = [segment.get_y(ti)[0] for ti in t]
            ovals = numpy.array(
                [self.eval(xi,yi) for xi,yi in zip(xvals,yvals)],
                dtype=numpy.complex)

            tseg = (t + k)/nsegs
            ax.plot(tseg, ovals.real, 'b-', **kwds)
            ax.plot(tseg, ovals.imag, 'r--', **kwds)

        if grid:
            ticks = numpy.linspace(0,1,nsegs+1)
            ax.xaxis.set_ticks(ticks)
            ax.grid(True, which='major')

        return fig

    def as_sympy(self):
        """Returns the differential as a Sympy expression."""
        return self._omega





if __name__=='__main__':
    print '=== Module Test: differentials.py ==='
    from sympy.abc import x,y

    f1 = (x**2 - x + 1)*y**2 - 2*x**2*y + x**4
    # []

    f2 = y**3 + 2*x**3*y - x**7
    # [x**3/(2*x**3 + 3*y**2), x*y/(2*x**3 + 3*y**2)]

    f3 = (y**2-x**2)*(x-1)*(2*x-3) - 4*(x**2+y**2-2*x)**2
    # does not match genus

    f4 = y**2 + x**3 - x**2
    # []

    f5 = (x**2 + y**2)**3 + 3*x**2*y - y**3
    # [x**2 + y**2]

    f6 = y**4 - y**2*x + x**2

    f7 = y**3 - (x**3 + y)**2 + 1
    # does not terminate

    f8 = x**6*y**3 + 2*x**3*y - 1
    # genus zero

    f9 = 2*x**7*y + 2*x**7 + y**3 + 3*y**2 + 3*y
    # (genus 9!)
    # [x**5/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x**4/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x**3/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x**2*y/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x**2/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x*y/(2*x**7 + 3*y**2 + 6*y + 3),
    #  x/(2*x**7 + 3*y**2 + 6*y + 3),
    #  y/(2*x**7 + 3*y**2 + 6*y + 3),
    #  1/(2*x**7 + 3*y**2 + 6*y + 3)]

    f10= (x**3)*y**4 + 4*x**2*y**2 + 2*x**3*y - 1
    # [x*y/(4*x**3*y**3 + 2*x**3 + 8*x**2*y),
    #  x/(4*x**3*y**3 + 2*x**3 + 8*x**2*y),
    #  1/(4*x**3*y**3 + 2*x**3 + 8*x**2*y)]


    f12 = y**3 - x**3*y + 2*x**7
    # [x**3/(-x**3 + 3*y**2), x*y/(-x**3 + 3*y**2)]

    f13 = x**4 + y**4 - 1
    # (fast! no singular points)
    # [x/(4*y**3), 1/(4*y**2), 1/(4*y**3)]

    # f = f2

    # import cProfile, pstats
    # cProfile.run(
    #     'D = differentials(f,x,y)',
    #     'differentials.profile',
    #     )
    # p = pstats.Stats('differentials.profile')
    # p.strip_dirs()
    # p.sort_stats('cumulative').print_stats(20)

    # print "\nDifferentials:"
    # for omega in D:
    #     sympy.pretty_print(omega)
    #     print
