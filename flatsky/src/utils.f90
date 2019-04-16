!////////////////////////////////////////////////////!
! * Utils for 2D Grid Analysis
!////////////////////////////////////////////////////!

module utils
  use random,    only: InitRandom, ranmar, Gaussian1
  use constants, only: iu, pi
  use general,   only: check_positive
  use grid2d,    only: elxy, elarray, elarrays_1d, elarrays_2d, wap, make_lmask
  use pstool,    only: binned_ells, power_binning, cb2cl
  implicit none

  private check_positive
  private InitRandom, ranmar, gaussian1
  private iu, pi
  private elxy, elarray, elarrays_1d, elarrays_2d, wap, make_lmask
  private binned_ells, power_binning, cb2cl


contains 

!//// Fourier modes ////!

subroutine el2d(nx,ny,D,els)
! return absolute value of multipole in 2D
  implicit none
  !I/O
  integer, intent(in) :: nx, ny
  double precision, intent(in), dimension(2) :: D
  double precision, intent(out), dimension(nx,ny) :: els
  !internal
  integer :: i, j
  double precision :: lx, ly

  do i = 1, nx
    lx = elxy(i,nx,D(1))
    do j = 1, ny
      ly = elxy(j,ny,D(2))
      if (lx==0.and.ly==0) cycle
      els(i,j) = dsqrt(lx**2+ly**2)
    end do
  end do

end subroutine el2d


subroutine elarrays(nx,ny,D,elx,ely,els,eli)
  implicit none
  integer, intent(in) :: nx, ny
  double precision, intent(in), dimension(2) :: D
  double precision, intent(out), dimension(nx,ny) :: elx, ely, els, eli

  call elarrays_2d((/nx,ny/),D,elx,ely,els,eli)

end subroutine elarrays


!//// Compute Cl from Fourier modes ////!

subroutine alm2bcl(bn,oL,nx,ny,D,Cb,alm1,alm2,spc)
  implicit none
  !inputs
  integer, intent(in) :: bn, nx, ny
  integer, intent(in), dimension(2) :: oL
  double precision, intent(in), dimension(2) :: D
  double complex, intent(in), dimension(nx,ny) :: alm1
  !optional
  character(*), intent(in), optional :: spc
  double complex, intent(in), dimension(nx,ny), optional :: alm2
  !f2py character(*) :: spc=''
  !f2py double complex :: alm2 = 0
  !docstr :: alm2 = alm1
  !outputs
  double precision, intent(out), dimension(bn) :: Cb
  !internal
  character(8) :: spc0
  double precision, allocatable :: C(:,:)
  double complex, allocatable :: alm0(:,:)

  spc0  = ''
  if (present(spc))  spc0 = spc

  !* 2D power spectrum
  allocate(C(nx,ny),alm0(nx,ny))
  alm0 = alm1
  if (present(alm2).and.sum(abs(alm2))==0) alm0 = alm1
  if (present(alm2).and.sum(abs(alm2))/=0) alm0 = alm2
  C = (alm1*conjg(alm0)+alm0*conjg(alm1))*0.5d0/(D(1)*D(2)) 
  deallocate(alm0)

  !* to 1D power spectrum
  call c2d2bcl(nx,ny,D,C,bn,oL,Cb,spc=spc0)

  deallocate(C)


end subroutine alm2bcl


subroutine c2d2bcl(nx,ny,D,Cl,bn,oL,Cb,spc)
! cl2d -> binned cl1d
  implicit none
  !I/O
  integer, intent(in) :: bn, nx, ny
  integer, intent(in), dimension(2) :: oL
  double precision, intent(in), dimension(2) :: D
  double precision, intent(in), dimension(nx,ny) :: Cl
  double precision, intent(out), dimension(bn) :: Cb
  !optional
  character(*), intent(in), optional :: spc
  !f2py character(*) :: spc=''
  !internal
  character(8) :: spc0
  double precision :: bp(bn+1), b(bn), els(nx,ny), lmask(nx,ny)
  double precision, dimension(bn) :: vAb

  spc0 = ''
  if (present(spc)) spc0 = spc

  call binned_ells(oL,bp,b,spc0)

  call make_lmask((/nx,ny/),D,oL,lmask)
  call el2d(nx,ny,D,els)
  call power_binning(bp,els,lmask*Cl,lmask,Cb,vAb)

end subroutine c2d2bcl


! Power spectrum interpolation

subroutine cl2c2d(nx,ny,D,lmin,lmax,Cl,c2d)
!* Transform Cl to Cl2D with linear interpolation
  implicit none
  !I/O
  integer, intent(in) :: nx, ny, lmin, lmax
  double precision, intent(in), dimension(2) :: D
  double precision, intent(in), dimension(0:lmax) :: Cl
  double precision, intent(out), dimension(nx,ny) :: c2d
  !internal
  logical :: p
  integer :: i, j, l0, l1
  double precision :: els(nx,ny)

  !check positivity
  call check_positive(Cl,p)

  call el2d(nx,ny,D,els)

  c2d = 0d0
  do i = 1, nx
    do j = 1, ny
      if (lmin>els(i,j).or.els(i,j)>lmax-1) cycle
      l0 = int(els(i,j))
      l1 = l0 + 1
      c2d(i,j) = Cl(l0) + (els(i,j)-l0)*(Cl(l1)-Cl(l0))
      if (c2d(i,j)>=0d0.or..not.p) cycle
      write(*,*) Cl(l0), Cl(l1), l0, els(i,j)
      stop 'error (cl2c2d): interpolated Cl is negative'
    end do
  end do

end subroutine cl2c2d


subroutine cb2c2d(bn,bc,nx,ny,D,eL,Cb,C2d,method0,bp)
! Interpolate binned Cl to 2D Cl
  implicit none
  !I/O
  integer, intent(in) :: bn, nx, ny
  integer, intent(in), dimension(2) :: eL
  double precision, intent(in), dimension(2) :: D
  double precision, intent(in), dimension(bn) :: bc, Cb
  double precision, intent(out), dimension(nx,ny) :: C2d
  !optional
  character(*), intent(in), optional :: method0
  !f2py character(*) :: method0=''
  double precision, intent(in), optional, dimension(bn+1) :: bp
  !internal
  character(8) :: m
  double precision, allocatable :: Cl(:), bp0(:)

  allocate(Cl(eL(2)),bp0(size(bc)+1)); Cl=0d0; bp0=0d0

  m = ''
  if(present(bp))      bp0 = bp
  if(present(method0)) m   = method0 

  !interpolate Cb -> Cl
  call cb2cl(bc,Cb,Cl,bp=bp0,method=m)

  !interpolate Cl -> C2d
  call cl2c2d(nx,ny,D,eL(1),eL(2),Cl,c2d)

  deallocate(Cl,bp0)

end subroutine cb2c2d


!//// Gaussian field generation ////!

subroutine gauss1alm(nx,ny,D,lmin,lmax,Cl,alm)
! Generate 1D-array random gaussian fields in 2D Fourier space for a given isotropic spectrum
! Note: satisfy a^*_l = a_{-l}
  implicit none
  ![input]
  ! ny --- x and y grid number
  ! D(2)  --- x and y length
  ! iL(2) --- min/max multipoles of the random gaussian fields
  ! Cl(:) --- power spectrum
  integer, intent(in) :: lmin, lmax, nx, ny
  double precision, intent(in), dimension(2) :: D
  double precision, intent(in), dimension(0:lmax) :: Cl
  ![output]
  ! alm[x,y] --- random gaussian fields of a nx x ny array
  double complex, intent(out), dimension(nx,ny) :: alm
  !internal
  integer :: i, j, n, l0, l1
  integer :: ijmin(2), ijmax(2)
  double precision :: x, y, dx, dy, d0, l
  double precision, allocatable :: amp(:), amp2d(:,:)

  ! check
  if(mod(nx,2)/=0.or.mod(ny,2)/=0) stop 'error (gaussian_alm) : nx and/or ny should be even integers'
 
  call InitRandom(-1)

  !* make cl on 2d grid
  allocate(amp(size(Cl)),amp2d(nx,ny))
  amp = 0d0
  d0 = D(1)*D(2)
  do i = lmin, lmax
    if (Cl(i)<0d0) then
      write(*,*) 'error: cl is negative', cl(i), i
      stop
    end if
    amp(i) = dsqrt(d0*Cl(i)*0.5d0)  ! \sqrt(\delta(l=0)*Cl(l)/2)
  end do
  amp2d = 0d0
  do i = 1, nx
    x = elxy(i,nx,D(1))
    do j = 1, ny
      y = elxy(j,ny,D(2))
      l = dsqrt(x**2+y**2)
      if(lmin>l.or.l>lmax-1) cycle
      l0 = int(l)
      l1 = l0 + 1
      amp2d(i,j) = amp(l0) + (l-l0)*(amp(l1)-amp(l0))
    end do
  end do
  deallocate(amp)

  !* alm=0 if i=1 or j=1 for symmetry
  !* center: (ic,jc) = (nx/2+1, ny/2+1)
  alm = 0d0

  !* maximum nn
  !ijmin = max ( 2, int( nn(:)*0.5d0 + 1 - iL(2)*D(:)/twopi ) )
  !ijmax = min ( nn(:), int( nn(:)*0.5d0 + 1 + iL(2)*D(:)/twopi ) + 1 )
  ijmin = 2
  ijmax = (/nx,ny/)

  !* check
  if(elxy(nx,nx,D(1))<lmax.or.elxy(ny,ny,D(2))<lmax) then
    write(*,*) 'error: inclusion of Fourier mode is incorrect'
    write(*,*) 'maximum ell should be lower than', elxy(nx,nx,D(1)), 'or', elxy(ny,ny,D(2))
    stop
  end if

  ! half side (i < ic)
  do i = ijmin(1), nx/2
    x = elxy(i,nx,D(1))
    do j = ijmin(2), ijmax(2)
      y = elxy(j,ny,D(2))
      l = dsqrt(x**2+y**2)
      if(l<lmin.or.l>lmax) cycle
      alm(i,j) = cmplx(Gaussian1(),Gaussian1())*amp2d(i,j)
    end do
  end do

  ! values on axis (i=ic) but avoid the origin (ell=0) 
  i = nx/2+1
  ! x=0
  do j = ijmin(2), ny/2
    y = elxy(j,ny,D(2))
    l = abs(y)
    if(l<lmin.or.l>lmax) cycle
    alm(i,j) = cmplx(Gaussian1(),Gaussian1())*amp2d(i,j)
  end do
  do j = ny/2+2, ijmax(2)
    alm(i,j) = conjg(alm(i,ny-j+2))
  end do
  
  ! the other half side (i>ic)
  do i = nx/2+2, ijmax(1)
    do j = ijmin(2), ijmax(2)
      alm(i,j) = conjg(alm(nx-i+2,ny-j+2))
    end do
  end do

  deallocate(amp2d)


end subroutine gauss1alm


subroutine gauss2alm(nx,ny,D,lmin,lmax,TT,TE,EE,tlm,elm)
  implicit none
  integer, intent(in) :: nx, ny, lmin, lmax
  double precision, intent(in), dimension(2) :: D
  double precision, intent(in), dimension(0:lmax) :: TT, TE, EE
  double complex, intent(out), dimension(nx,ny) :: tlm, elm
  integer :: i, j
  double precision, allocatable :: uni(:), TT2d(:,:), TE2d(:,:), EE2d(:,:)
  double complex, allocatable :: ulm(:,:)

  allocate(uni(0:lmax),ulm(nx,ny)); uni=1d0; ulm=0d0

  call gauss1alm(nx,ny,D,lmin,lmax,TT,tlm)
  call gauss1alm(nx,ny,D,lmin,lmax,uni,ulm)

  allocate(TT2d(nx,ny),TE2d(nx,ny),EE2d(nx,ny))
  call cl2c2d(nx,ny,D,lmin,lmax,TT,TT2d)
  call cl2c2d(nx,ny,D,lmin,lmax,TE,TE2d)
  call cl2c2d(nx,ny,D,lmin,lmax,EE,EE2d)

  elm = 0d0
  do i = 1, nx
    do j = 1, ny
      if (TT2d(i,j)==0d0) cycle
      elm(i,j) = (TE2d(i,j)/TT2d(i,j))*tlm(i,j) + ulm(i,j)*dsqrt(EE2d(i,j)-TE2d(i,j)**2/TT2d(i,j))
    end do
  end do

  deallocate(TT2d,TE2d,EE2d,ulm,uni)

end subroutine gauss2alm


!//// Window function //////////////////////////////////////////////////////////////////////////////!

subroutine window_sin(nx,ny,D,W,ap,cut)
  implicit none
  !I/O
  integer, intent(in) :: nx, ny
  double precision, intent(in), dimension(2) :: D
  double precision, intent(out), dimension(nx,ny) :: W
  !optional
  double precision, intent(in), optional :: ap, cut
  !f2py double precision :: ap = 1
  !f2py double precision :: cut = 1
  !internal
  integer :: i, j
  double precision :: a, c, xi, xj, sx ,sy

  sx = D(1)/dble(nx)
  sy = D(2)/dble(ny)

  a  = 1d0
  if (present(ap)) a = ap

  c  = 1d0
  if (present(cut)) c = cut

  do i = 1, nx
    do j = 1, ny
      xi = dble(i-1-(nx-1)*0.5)*sx
      xj = dble(j-1-(ny-1)*0.5)*sy
      W(i,j) = wap(D(1),abs(xi),a,c)*wap(D(2),abs(xj),a,c)
    end do
  end do

end subroutine window_sin


subroutine window_norm(nx,ny,W,num,Wn)
  implicit none
  integer, intent(in) :: nx, ny, num
  double precision, intent(in), dimension(nx,ny) :: W
  double precision, intent(out), dimension(0:num) :: Wn
  integer :: n

  Wn(0) = 1d0
  do n = 1, num
    Wn(n) = sum(W**n)/dble(nx*ny)
  end do

end subroutine window_norm


subroutine window_norm_x(nx,ny,W1,W2,num,Wn)
  implicit none
  integer, intent(in) :: nx, ny, num
  double precision, intent(in), dimension(nx,ny) :: W1, W2
  double precision, intent(out), dimension(0:num,0:num) :: Wn
  integer :: n, m

  do n = 0, num
    do m = 0, num
      Wn(n,m) = sum(W1**n*W2**m)/dble(nx*ny)
    end do
  end do

end subroutine window_norm_x


subroutine rotation(nx,ny,rot,QU,rQU,rtype)
  implicit none
  character(*), intent(in) :: rtype
  integer, intent(in) :: nx, ny
  double precision, intent(in), dimension(nx,ny) :: rot
  double precision, intent(in), dimension(nx,ny,2) :: QU
  double precision, intent(out), dimension(nx,ny,2) :: rQU
  double precision, allocatable :: tmp(:,:,:)  

  allocate(tmp(nx,ny,2))
  select case(rtype)
  case('l')
    tmp(:,:,1) = QU(:,:,1) - QU(:,:,2)*2d0*rot
    tmp(:,:,2) = QU(:,:,2) + QU(:,:,1)*2d0*rot
  case('f')
    tmp(:,:,1) = QU(:,:,1)*dcos(2d0*dble(rot)) - QU(:,:,2)*dsin(2d0*dble(rot))
    tmp(:,:,2) = QU(:,:,2)*dcos(2d0*dble(rot)) + QU(:,:,1)*dsin(2d0*dble(rot))
  case default
    stop 'error (rotation): rotation type not specified'
  end select
  rQU = tmp
  deallocate(tmp)

end subroutine rotation


subroutine get_angle(nx,ny,D,theta,phi)
  implicit none
  integer, intent(in) :: nx, ny
  double precision, intent(in), dimension(2) :: D
  double precision, intent(out), dimension(ny) :: theta
  double precision, intent(out), dimension(nx) :: phi
  integer :: a, b

  do a = 1, nx
    phi(a)   = dble(a-1-(nx-1)*0.5)*D(1)/dble(nx)
  end do
  do b = 1, ny
    theta(b) = pi/2d0 - dble(b-1-(ny-1)*0.5)*D(2)/dble(ny)
  end do

end subroutine get_angle


subroutine cutmap(ox,oy,cx,cy,omap,cmap)
  implicit none
  integer, intent(in) :: ox,oy,cx,cy
  double precision, intent(in), dimension(ox,oy) :: omap
  double precision, intent(out), dimension(cx,cy) :: cmap
  integer :: nx, ny

  do nx = 1, cx
    do ny = 1, cy
      cmap(nx,ny) = omap(nx+ox/2-cx/2,ny+oy/2-cy/2)
    end do
  end do
 
end subroutine cutmap


end module utils

