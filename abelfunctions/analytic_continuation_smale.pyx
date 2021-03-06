"""
Analytic Continuation: Smale's Alpha Theory
===========================================

This module implements subclass of :class:AnalyticContinuator which uses
Smale's alpha theory for analytically continuing y-roots. This
AnalyticContinuator is only effective away from the branch points and
singular points of the curve since its primary mechanism is Newton
iteration. A different AnalyticContinuator, such as
:class:AnalyticContinuatorPuiseux, is required in order to analytically
continue to such points.

Functions::

  factorial   -- factorial function
  newton      -- Newton iteration of y-roots
  smale_alpha -- Smale's alpha function
  smale_beta  -- Smale's beta function
  smale_gamma -- Smale's gamma function

Classes::

  UnivariatePolynomial   -- fast univatriate polynomial evaluation
  MultivariatePolynomial -- fast bi-variate polynomial evaluation

Globals::

  ABELFUNCTIONS_SMALE_ALPHA0

Authors
-------

* Chris Swierczewski (January 2013)
"""

cimport cython
import numpy
cimport numpy
import sympy

from .analytic_continuation cimport AnalyticContinuator
from .riemann_surface cimport RiemannSurface
from .riemann_surface_path cimport RiemannSurfacePathPrimitive
from .polynomials cimport MultivariatePolynomial

cdef extern from "math.h":
    double sqrt(double)

cdef extern from "complex.h":
    double creal(complex)
    double cimag(complex)
    double cabs(complex)

cdef double ABELFUNCTIONS_SMALE_ALPHA0 = 1.1884471871911697 #(13-2*sqrt(17))/4


cdef int factorial(int n) nogil:
    """Fast evaluation of `n` factorial.

    Arguments
    ---------
    n : int

    Returns
    -------
    :math:`n!`
    """
    cdef int k, nfac = 1
    with nogil:
        for k in range(1,n+1):
            nfac *= k
        return nfac


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef complex newton(MultivariatePolynomial[:] df,
                    complex xip1,
                    complex yij):
    """Newton iterate a y-root yij of a polynomial :math:`f = f(x,y)`, lying
    above some x-point xi, to the x-point xip1.

    Given :math:`f(x_i,y_{i,j}) = 0` and some complex number
    :math:`x_{i+1}`, this function returns a complex number
    :math:`y_{i+1,j}` such that :math:`f(x_{i+1},y_{i+1,j}) = 0`.

    Arguments
    ---------
    df : MultivariatePolynomial[:]
        A list of all of the y-derivatives of f, including the function
        f itself.
    xip1 : complex
        The x-point to analytically continue to.
    yij: complex
        A y-root at xi. The root that we'll analytically continue.

    Returns
    -------
    A y-root of f lying above `xip1`.
    """
    cdef MultivariatePolynomial df0 = df[0]
    cdef MultivariatePolynomial df1 = df[1]
    cdef complex step = 1.0
    cdef complex df1y
    while cabs(step) > 1e-14:
        # if df is not invertible then we are at a critical point.
        df1y = df1.eval(xip1,yij)
        if cabs(df1y) < 1e-14:
            return yij
        step = df0.eval(xip1,yij)/df1y
        yij -= step
    return yij


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double smale_beta(MultivariatePolynomial[:] df,
                       complex xip1,
                       complex yij):
    """Compute the Smale beta function at this y-root.

    The Smale beta function is simply the size of a Newton iteration

    Arguments
    ---------
    df : MultivariatePolynomial[:]
        A list of all of the y-derivatives of f, including the function
        f itself.
    xip1 : complex
        The x-point to analytically continue to.
    yij: complex
        A y-root at xi. The root that we'll analytically continue.

    Returns
    -------
    :math:`\beta(f,x_{i+1},y_{i,j})`.
    """
    cdef MultivariatePolynomial df0 = df[0]
    cdef MultivariatePolynomial df1 = df[1]
    return cabs(df0.eval(xip1,yij)/df1.eval(xip1,yij))


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double smale_gamma(MultivariatePolynomial[:] df,
                        complex xip1,
                        complex yij):
    """Compute the Smale gamma function.

    Arguments
    ---------
    df : MultivariatePolynomial
        a list of all of the y-derivatives of f (up to the y-degree)
    xip1 : complex
        the x-point to analytically continue to
    yij : complex
        a y-root at xi. The root that we'll analytically continue.

    Returns
    -------
    double
        The Smale gamma function.
    """
    cdef MultivariatePolynomial df0 = df[0]
    cdef MultivariatePolynomial df1 = df[1]
    cdef MultivariatePolynomial dfn
    cdef int n, deg = df0.deg
    cdef complex df1y = df1.eval(xip1,yij)
    cdef double gamman, gamma = 0

    for n in range(2,deg+1):
        dfn = df[n]
        gamman = cabs(dfn.eval(xip1,yij) / (factorial(n)*df1y))
        gamman = gamman**(1.0/(n-1.0))
        if gamman > gamma:
            gamma = gamman
    return gamma


cdef double smale_alpha(MultivariatePolynomial[:] df,
                        complex xip1,
                        complex yij):
    """Compute Smale alpha.

    Arguments
    ---------
    df : MultivariatePolynomial
        a list of all of the y-derivatives of f (up to the y-degree)
    xip1 : complex
        the x-point to analytically continue to
    yij : complex
        a y-root at xi. The root that we'll analytically continue.

    Returns
    -------
    double
        The Smale alpha function.
    """
    return smale_beta(df,xip1,yij) * smale_gamma(df,xip1,yij)


cdef class AnalyticContinuatorSmale(AnalyticContinuator):
    """Riemann surface path analytic continuation using Smale's alpha
    theory.

    When sufficiently far away from branch points and singular point of
    the curve we can use Newton iteration to analytically continue the
    y-roots of the curve along paths in :math:`\mathbb{C}_x`. Smale's
    alpha theory is used to determine an optimal step size in
    :math:`\mathbb{C}_x` to ensure that Newton iteration will not only
    succeed with each y-root but the y-roots will not "collide" or swap
    places with each other. See [XXX REFERENCE XXX] for more
    information.

    .. note::

        This class uses the functions :func:`newton`,
        :func:`smale_alpha`, :func:`smale_beta`, and
        :func:`smale_gamma`, defined in this module.

    Attributes
    ----------
    RS : RiemannSurface
        The Riemann surface on which analytic continuation takes place.
    df : MultivariatePolynomial[:]
        A list of all of the y-derivatives of the curve, `f = f(x,y)`.
        These are used by Smale's alpha theory.
    """
    def __init__(self, RiemannSurface RS):
        cdef int deg = sympy.degree(RS.f,RS.y)
        self.df = numpy.array(
            [MultivariatePolynomial(sympy.diff(RS.f,RS.y,k),RS.x,RS.y)
            for k in range(deg+1)],
            dtype=MultivariatePolynomial)

        self.deg = deg
        AnalyticContinuator.__init__(self, RS)

    cpdef complex[:] analytically_continue(
            self,
            RiemannSurfacePathPrimitive gamma,
            complex xi,
            complex[:] yi,
            complex xip1):
        """Analytically continues the fibre `yi` from `xi` to `xip1` using
        Smale's alpha theory.

        Arguments
        ---------
        gamma : RiemannSurfacePathPrimitive
            A Riemann surface path-type object.
        xi : complex
            The starting complex x-value.
        yi: complex[:]
            The starting complex y-fibre lying above `xi`.
        xip1: complex
            The target complex x-value.

        Returns
        -------
        complex[:]
            The y-fibre lying above `xip1`.
        """
        cdef int j,k
        cdef complex xiphalf
        cdef complex[:] yiphalf, yip1
        cdef complex yij, yik
        cdef double betaij, betaik

        # return the current fibre if the step size is too small
        if cabs(xip1-xi) < 1e-15:
            return yi

        # first determine if the y-fibre guesses are 'approximate
        # solutions'. if any of them are not then refine the step by
        # analytically continuing to an intermediate "time"
        for j in range(self.deg):
            yij = yi[j]
            if smale_alpha(self.df, xip1, yij) > ABELFUNCTIONS_SMALE_ALPHA0:
                xiphalf = (xi + xip1)/2.0
                yiphalf = self.analytically_continue(
                    gamma, xi, yi, xiphalf)
                yip1 = self.analytically_continue(
                    gamma, xiphalf, yiphalf, xip1)
                return yip1

        # next, determine if the approximate solutions will converge to
        # different associated solutions
        for j in range(self.deg):
            yij = yi[j]
            betaij = smale_beta(self.df, xip1, yij)
            for k in range(j+1, self.deg):
                yik = yi[k]
                betaik = smale_beta(self.df, xip1, yik)

                if cabs(yij-yik) < 3*(betaij + betaik):  #XXX (was 2)
                    # approximate solutions don't lead to distinct
                    # roots. refine the step by analytically continuing
                    # to an intermedite time
                    xiphalf = (xi + xip1)/2.0
                    yiphalf = self.analytically_continue(
                        gamma, xi, yi, xiphalf)
                    yip1 = self.analytically_continue(
                        gamma, xiphalf, yiphalf, xip1)
                    return yip1

        # finally, since we know that we have approximate solutions that
        # will converge to difference associated solutions we will
        # Netwon iterate
        yip1 = numpy.array(
            [newton(self.df,xip1,yi[j]) for j in range(self.deg)],
            dtype=complex)
        return yip1


