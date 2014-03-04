"""
RiemannSurfaces
===============

Authors
-------

* Chris Swierczewski (January 2014)
"""

import numpy
import scipy
import scipy.integrate
import scipy.linalg
import sympy

from .riemann_surface_path_factory import RiemannSurfacePathFactory
from .differentials import differentials
from .singularities import genus


cdef class RiemannSurface:
    """A Riemann surface defined by a complex plane algebraic curve.

    Attributes
    ----------
    f : sympy.Expression
        The algebraic curve representing the Riemann surface.
    x,y : sympy.Symbol
        The dependent and independent variables, respectively.
    """
    property f:
        def __get__(self):
            return self._f
    property x:
        def __get__(self):
            return self._x
    property y:
        def __get__(self):
            return self._y
    property deg:
        def __get__(self):
            return self._deg

    property PF:
        def __get__(self):
            return self.PathFactory

    def __init__(self, f, x, y, base_point=None, base_sheets=None, kappa=3./5):
        """Construct a Riemann surface.

        Arguments
        ---------
        f : sympy.Expression
            The algebraic curve representing the Riemann surface.
        x,y : sympy.Symbol
            The dependent and independent variables, respectively.
        base_point : complex, optional
            A custom base point for the Monodromy group.
        base_sheets : complex list, optional
            A custom ordering of the sheets at the base point.
        kappa : double

            A scaling parameter greater than 0 but less than 1 used to
            define the radii of the x-path circles around the curve's
            branch points.
        """
        self._f = f
        self._x = x
        self._y = y
        self._deg = sympy.degree(f,y)
        self.PathFactory = RiemannSurfacePathFactory(self)

    def __repr__(self):
        s = 'Riemann surface defined by the algebraic curve %s'%(self.f)
        return s

    def __call__(self, alpha, beta):
#        return self.point(alpha, beta)
        pass

    def show_paths(self):
        self.PathFactory.XSkel.show_paths()

    def point(self, alpha, beta):
        raise NotImplementedError('Need to define a RiemannSurfacePoint '
                                  'class before this can work as intended.')

    #
    # Monodromy: expose some methods / properties of self.Monodromy
    # without subclassing (since it doesn't make sense that a Riemann
    # surface is a type of Monodromy group.)
    #
    def monodromy_group(self):
        return self.PathFactory.monodromy_group()

    def base_point(self):
        return self.PathFactory.base_point()

    def base_sheets(self):
        return self.PathFactory.base_sheets()

    def base_lift(self):
        return self.base_sheets()

    def branch_points(self):
        return self.PathFactory.branch_points()

    # #
    # # Homology: expose some methods / properties of self.Homology
    # # without subclassing (since it doesn't make sense that a Riemann
    # # surface is a type of Monodromy group.)
    # #
    # def homology(self, verbose=False):
    #     d = homology(self.f, self.x, self.y,
    #                  base_point=self._base_point,
    #                  base_sheets=self._base_sheets,
    #                  verbose=True)
    #     if verbose:
    #         return d
    #     else:
    #         return (d['a-cycles'],d['b-cycles'])

    def holomorphic_differentials(self):
        """Returns a basis of holomorphic differentials defined on the Riemann
        surface.

        """
        return differentials(self.f, self.x, self.y)

    def differentials(self):
        return self.holomorphic_differentials()

    def genus(self):
        return genus(self.f, self.x, self.y)

    # def integrate(self, omega, x, y, path, **kwds):
    #     """Integrates the differential `omega` about the Riemann surface path
    #     `path`.

    #     .. note::

    #         This is a most likely going to be a placeholder until an
    #         Integrator-like object is created.

    #     Arguments
    #     ---------
    #     omega : Differential
    #         A holomorphic differential.
    #     path : RiemannSurfacePathPrimitive
    #         A path on the Riemann surface.

    #     Returns
    #     -------
    #     complex
    #         The integral of `omega` about the path `gamma`.

    #     """
    #     val = numpy.complex(0.0)
    #     omega = sympy.lambdify((x,y),omega,'numpy')

    #     for gamma_k in gamma.segments:
    #         def integrand(ti):
    #             dxdt = gamma_k.get_dxdt(ti)
    #             xi = gamma_k.get_x(ti)
    #             yi = gamma_k.get_y(ti)
    #             return omega(xi,yi[0]) * dxdt

    #         val += scipy.integrate.romberg(integrand, 0, 1, **kwds)

    #     return val


    #     def period_matrix(self, riemann_matrix=True):
    #         """Returns the period matrix of this curve.

    #         The period matrix of the curve is built by integrating a
    #         basis of holomorphic differentials on the Riemann surface
    #         about the a- and b-cycles of its homology.

    #         This function either returns a :math:`g \times 2g` matrix of
    #         the a- and b-cycle integrals, :math:`(A \, B)` or, if
    #         `riemann_matrix` is set to `True`, will return the Riemann
    #         matrix .. math::

    #             \Omega = A^{-1} B

    #         Arguments
    #         ---------
    #         riemann_matrix : default `False`
    #             If False, returns the :math:`g \times 2g` matric of a-
    #             and b-periods. Otherwise, returns a :math:`g \times g`
    #             Riemann matrix.

    #         Returns
    #         -------
    #         numpy.array
    #            Returns a Numpy array of the periods or a Riemann matrix,
    #            depending on the value of `riemann_matrix`.
    #         """
    #         omegas = self.holomorphic_differentials()
    #         base_point = self.base_point()
    #         base_sheets = self.base_sheets()
    #         G = self.mondodromy_graph()
    #         g = self.genus()
    #         x = self.x
    #         y = self.y

    #     # store the values of the integrals of the c-cycles but only for
    #     # the ones where the linear combination index is non-zero. that
    #     # is, only compute the integrals of the c-cycles that are
    #     # actually used
    #     c_cycles = self._c_cycles()
    #     m = len(c_cycles)
    #     lincombs = self._linear_combinations()
    #     c_integrals = dict.fromkeys(range(m),
    #                                 numpy.zeros(len(differentials),
    #                                             dtype=numpy.complex))
    #     c_needed = [j for i in range(2*g) for j in range(m)
    #                 if lincombs[i,j] != 0]

    #     for k in c_needed:
    #         c_cycle = c_cycles[k]
    #         gamma = RiemannSurfacePath(self,(base_point,base_sheets),
    #                                    cycle=c_cycle)
    #         c_integrals[k] = [
    #             self.integrate(omega, x, y, gamma) for omega in differentials
    #             ]

    #     # now take appropriate linear combinations to compute the
    #     # integrals of the differentials around the a- and b-cycles
    #     tau = numpy.zeros((g,2*g), dtype=numpy.complex)
    #     for i in range(g):
    #         for j in range(2*g):
    #             # make sure that everything beyond what we need is zero
    #             tau[i][j] = scipy.dot(lincombs[j,:], c_integrals[:,i])
    #     assert tau == scipy.dot(lincombs, c_integrals) # XXX

    #     A = tau[:g,:g]
    #     B = tau[:g,g:]

    #     if riemann_matrix:
    #         Omega = numpy.dot(numpy.linalg.inv(A), B)
    #         return Omega
    #     else:
    #         return A,B


if __name__ == '__main__':
    import sympy
    from sympy.abc import x,y

    f0 = y**3 - 2*x**3*y - x**8
    f1 = (x**2 - x + 1)*y**2 - 2*x**2*y + x**4
    f2 = -x**7 + 2*x**3*y + y**3
    f3 = (y**2-x**2)*(x-1)*(2*x-3) - 4*(x**2+y**2-2*x)**2
    f4 = y**2 + x**3 - x**2
    f5 = (x**2 + y**2)**3 + 3*x**2*y - y**3
    f6 = y**4 - y**2*x + x**2
    f7 = y**3 - (x**3 + y)**2 + 1
    f8 = (x**6)*y**3 + 2*x**3*y - 1
    f9 = 2*x**7*y + 2*x**7 + y**3 + 3*y**2 + 3*y
    f10 = (x**3)*y**4 + 4*x**2*y**2 + 2*x**3*y - 1
    f11 = y**2 - (x-2)*(x-1)*(x+1)*(x+2)
    f12 = x**4 + y**4 - 1

    f = f2
    X = RiemannSurface(f, x, y)