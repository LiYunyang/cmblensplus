import numpy as np
import sys
import constants as c
import basic
import curvedsky
import misctools

if sys.version_info[:3] > (3,0):
  import pickle
elif sys.version_info[:3] > (2,5,2):
  import cPickle as pickle


#////////// Frequency Spectrum //////////#

def Int_Planck(nu,T): 
    '''
    Black body I(nu)
    nu [GHz]
    '''
    nu0 = nu*1e9
    return 2*c.h*nu0**3/c.c**2 * (np.exp(c.h*nu0/c.kB/T)-1.)**(-1)


def Int_dust(nu,Td=19.6,beta=1.53): 
    '''
    Dust I(nu) as a modified Black body
    Td, beta: values from arXiv 1801.04945
    nu [GHz]
    '''
    return (nu*1e9)**beta*Int_Planck(nu,Td)


def RJfunc(nu,T):
    """
    nu [GHz]
    """
    return 2*(nu*1e9)**2/c.c**2 * c.kB*T


def Int_Planck_deriv(nu,T):
    """
    nu [GHz]
    """
    nu0 = nu*1e9
    return Int_Planck(nu,T) * (np.exp(c.h*nu0/c.kB/T)*c.h*nu0/c.kB/T**2)/(np.exp(c.h*nu0/c.kB/T)-1.)


#////////// Gaussian beam //////////#

def beam(theta,lmax):

    ac2rad = np.pi/10800.
    L      = np.linspace(0,lmax,lmax+1)
    beam   = np.exp(L*(L+1)*(theta*ac2rad)**2/(16.*np.log(2.)))
    return beam


#////////// Noise spectrum //////////#

def nl_white(sigma,theta,lmax,Tcmb=2.72e6):

    return (sigma*ac2rad/Tcmb)**2*beam(theta,lmax)**2


#////////// Angular power spectrum /////////#

def aps(snmin,snmax,lmax,falm,odd=True,verbose=True,w2=1.,mtype=['T','E','B'],fname=None,loadcls=True,overwrite=False):
    '''
    Compute CMB aps (TT,EE,BB,TE,TB,EB)
    '''

    if verbose: print('aps')

    if odd:
        cn = 6
    else:
        cn = 4

    sn  = snmax - snmin + 1
    cls = np.zeros((sn,cn,lmax+1))

    for i in range(snmin,snmax+1):

        if verbose: print(i)

        ii = i - snmin

        if fname is not None and misctools.check_path(fname[i],verbose=verbose,overwrite=overwrite):

            if loadcls:
                cls[ii,:,:] = np.loadtxt(fname[i],unpack=True)[1:,:]

        else:
        
            # load cmb alms
            if 'T' in mtype:  Talm = pickle.load(open(falm['T'][i],"rb"))
            if 'E' in mtype:  Ealm = pickle.load(open(falm['E'][i],"rb"))
            if 'B' in mtype:  Balm = pickle.load(open(falm['B'][i],"rb"))

            # compute cls
            if 'T' in mtype:  cls[ii,0,:] = curvedsky.utils.alm2cl(lmax,Talm)
            if 'E' in mtype:  cls[ii,1,:] = curvedsky.utils.alm2cl(lmax,Ealm)
            if 'B' in mtype:  cls[ii,2,:] = curvedsky.utils.alm2cl(lmax,Balm)
            if 'T' in mtype and 'E' in mtype:  cls[ii,3,:] = curvedsky.utils.alm2cl(lmax,Talm,Ealm)
            if odd and 'T' in mtype and 'B' in mtype:
                cls[ii,4,:] = curvedsky.utils.alm2cl(lmax,Talm,Balm)
            if odd and 'E' in mtype and 'B' in mtype:
                cls[ii,5,:] = curvedsky.utils.alm2cl(lmax,Ealm,Balm)

            # correct normalization
            if w2 != 1.:
                cls[ii,:,:] /= w2

        # save to file
        if fname is not None and overwrite:
            L = np.linspace(0,lmax,lmax+1)
            np.savetxt(fname[i],np.concatenate((L[None,:],cls[ii,:,:])).T)

    return cls


def apsx(snmin,snmax,lmax,falm,galm,verbose=True,mtype=['T','E','B']):
    '''
    Compute CMB aps (T0T1,E0E1,B0B1)
    '''

    if verbose: print('apsx')

    sn  = snmax - snmin + 1
    cls = np.zeros((sn,3,lmax+1))

    for i in range(snmin,snmax+1):

        if verbose: print(i)
        ii = i - snmin

        # load cmb alms
        if 'T' in mtype:  Talm = pickle.load(open(falm['T'][i],"rb"))
        if 'E' in mtype:  Ealm = pickle.load(open(falm['E'][i],"rb"))
        if 'B' in mtype:  Balm = pickle.load(open(falm['B'][i],"rb"))
        if 'T' in mtype:  talm = pickle.load(open(galm['T'][i],"rb"))
        if 'E' in mtype:  ealm = pickle.load(open(galm['E'][i],"rb"))
        if 'B' in mtype:  balm = pickle.load(open(galm['B'][i],"rb"))

        # compute cls
        if 'T' in mtype:  cls[ii,0,:] = curvedsky.utils.alm2cl(lmax,Talm,talm)
        if 'E' in mtype:  cls[ii,1,:] = curvedsky.utils.alm2cl(lmax,Ealm,ealm)
        if 'B' in mtype:  cls[ii,2,:] = curvedsky.utils.alm2cl(lmax,Balm,balm)

    return cls


