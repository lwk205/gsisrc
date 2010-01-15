module compact_diffs
!$$$   module documentation block
!                .      .    .                                       .
! module:    compact_diffs   global compact diff derivative stuff
!   prgmmr: parrish          org: np22                date: 2005-01-21
!
! abstract: contains routines to initialize constants and compute 
!             compact difference approximations to derivatives
!             in latitude and longitude on the sphere.
!
! program history log:
!   2005-01-21  parrish
!   2005-01-26  treadon - add init_compact_diffs
!
! subroutines included:
!   sub init_compact_diffs  - initialize parameters used by compact diffs
!   sub create_cdiff_coefs  - create arrays for global compact diffs
!   sub destroy_cdiff_coefs - remove arrays for global compact diffs
!   sub stvp2uv             - psi,chi --> u,v
!   sub uv2vordiv           - u,v --> vor,div
!   sub xdcirdp             - get x-derivatives on sphere
!   sub xmulbv              - multiply banded matrix by vector
!   sub xbacbv              - back substitution phase of banded matrix inversion
!   sub tstvp2uv            - adjoint of stvp2uv
!   sub ydsphdp             - compute y-derivatives on sphere
!   sub ymulbv              - multiply banded matrix by vector
!   sub ybacbv              - back substitution phase of banded matrix inversion
!   sub tydsphdp            - adjoint of ydspdp
!   sub ybacvb              - back substitution for banded matrix inversion
!   sub ymulvb              - multiply vector by banded matrix
!   sub inisph              - init coefs for compact differencing on sphere
!   sub cdcoef              - compute differencing coefficients
!   sub dfcd                - compute coefs for compact/lagrange schemes
!   sub aldub               - ldu decomposition
!   sub dlinvmm             - invert linear systems
!   sub dlufm               - perform l-u decomposition
!   sub dlubmm              - invert matrix
!   sub compact_dlon
!   sub tcompact_dlon
!   sub compact_dlat
!   sub tcompact_dlat
!   sub compact_delsqr
!   sub tcompact_delsqr
!   sub compact_grad
!   sub compact_grad_ad
!   sub compact_div
!   sub compact_div_ad
!
! Variable Definitions:
!   def noq       - 1/4 intended order of accuracy for stvp<-->uv routines
!   def coef      - an array containing high-order compact differencing
!                   coefficients
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block

  use kinds, only: r_kind,i_kind
  implicit none

! set default to private
  private
! set subroutines to public
  public :: init_compact_diffs
  public :: create_cdiff_coefs
  public :: destroy_cdiff_coefs
  public :: stvp2uv
  public :: uv2vordiv
  public :: xdcirdp
  public :: xmulbv
  public :: xbacbv
  public :: tstvp2uv
  public :: ydsphdp
  public :: ymulbv
  public :: ybacbv
  public :: tydsphdp
  public :: ybacvb
  public :: ymulvb
  public :: inisph
  public :: cdcoef
  public :: dfcd
  public :: aldub
  public :: dlinvmm
  public :: dlufm
  public :: dlubmm
  public :: compact_dlon
  public :: tcompact_dlon
  public :: compact_dlat
  public :: tcompact_dlat
  public :: compact_delsqr
  public :: tcompact_delsqr
  public :: compact_grad
  public :: compact_grad_ad
  public :: compact_div
  public :: compact_div_ad
! set passed variables to public
  public :: coef,noq

  integer(i_kind) noq
  logical,save :: initialized_=.false.
  real(r_kind),allocatable,dimension(:):: coef


contains


  subroutine init_compact_diffs
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    init_compact_diffs
!   prgmmr: treadon          org: np23               date:  2003-11-24
!
! abstract: initialize cost function variables to defaults
!
! program history log:
!   2005-01-26  treadon
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!
!$$$
    implicit none
    
    noq=3_i_kind
    return
  end subroutine init_compact_diffs


  subroutine create_cdiff_coefs
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    create_cdiff_coefs    create arrays for global compact diffs
!   prgmmr: parrish          org: np22                date: 2005-01-21
!
! abstract: create coefs for global compact difference approximations to 
!            derivatives in lat, lon
!
! program history log:
!   2005-01-21  parrish
!   2009-02-20  todling - allow multiple init/destroy
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione
  use gridmod, only: nlat,nlon
  implicit none

  if(initialized_) return
  allocate(coef(3*nlat+4*(2*(noq+5_i_kind)+ione)*(nlat+nlon/2)))
  initialized_=.true.

  return
  end subroutine create_cdiff_coefs


  subroutine destroy_cdiff_coefs
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    destroy_cdiff_coefs  deallocates array for global compact diffs
!   prgmmr: parrish          org: np22                date: 2005-01-21
!
! abstract: deallocates array for global compact diffs
!
! program history log:
!   2005-01-21  parrish
!   2005-03-03  treadon - add implicit none
!   2009-02-20  todling - allow multiple init/destroy
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    implicit none
    if(.not.initialized_) return
    deallocate(coef)
    initialized_=.false.

    return
  end subroutine destroy_cdiff_coefs


  subroutine stvp2uv(work1,work2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    stvp2uv compute uv from streamfunction/velocity potential
!   prgmmr: purser           org: np20                 date: 1994-01-01
!
! abstract: computes uv from streamfunction/velocity potential by
!           calculating gradient of a scalar field using high-order
!           compact differencing on a spherical grid.
!
! program history log:
!   1994-05-15  parrish,d. elimanate memory bank conflicts
!   1994-05-17  parrish,d. reverse order of longitude and latitude
!   2004-07-27  treadon - add only on use declarations; add intent in/out
!   2004-10-26  kleist - fix sign error
!   2009-04-19  derber - modified interface
!
!   input argument list:
!     work1  - array containing the streamfunction 
!     work2  - array containing the velocity potential 
!
!   output argument list:
!     work1  - array containing the u velocity 
!     work2  - array containing the v velocity 
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$

  use constants, only: ione,zero
  use gridmod, only: nlon,nlat,sinlon,coslon
  implicit none

! Declare passed variables
  real(r_kind),dimension(nlat,nlon),intent(inout) :: work1,work2

! Declare local variables  
  integer(i_kind) lbcoy2,lcy,lbcoy1,lacoy1,lacoy2,ix,iy,nbp,nya
  integer(i_kind) nxh,nxa,lacox2,lbcox2,lacox1,lbcox1,ny,i,j
  real(r_kind) polsu,polnu,polnv,polsv
  real(r_kind),dimension(nlon):: grid3n,grid3s,grid1n,grid1s
  real(r_kind),dimension(nlat-2_i_kind,nlon):: a,b,grid1,grid2,grid3,grid4

  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp

  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione
  
  do j=1,nlon
     do i=2,nlat-ione
        a(i-1,j)=work1(i,j)
        b(i-1,j)=work2(i,j)
     end do
  end do
  
  call xdcirdp(a,grid1,coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)
  call xdcirdp(b,grid3,coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)
  
  call ydsphdp(a,grid2,coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)
  call ydsphdp(b,grid4,coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)

!  make corrections for convergence of meridians:
  do ix=1,nlon
     do iy=1,ny
        grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)+grid4(iy,ix)
        grid3(iy,ix)=grid3(iy,ix)*coef(lcy+iy)-grid2(iy,ix)
     enddo
  enddo
  polnu=zero
  polnv=zero
  polsu=zero
  polsv=zero
  do ix=1,nlon
     polnu=polnu+grid3(ny,ix)*coslon(ix)-grid1(ny,ix)*sinlon(ix)
     polnv=polnv+grid3(ny,ix)*sinlon(ix)+grid1(ny,ix)*coslon(ix)
     polsu=polsu+grid3(1 ,ix)*coslon(ix)+grid1(1 ,ix)*sinlon(ix)
     polsv=polsv+grid3(1 ,ix)*sinlon(ix)-grid1(1 ,ix)*coslon(ix)
  end do
  polnu=polnu/float(nlon)
  polnv=polnv/float(nlon)
  polsu=polsu/float(nlon)
  polsv=polsv/float(nlon)
  do ix=1,nlon
     grid3n(ix)= polnu*coslon(ix)+polnv*sinlon(ix)
     grid1n(ix)=-polnu*sinlon(ix)+polnv*coslon(ix)
     grid3s(ix)= polsu*coslon(ix)+polsv*sinlon(ix)
     grid1s(ix)= polsu*sinlon(ix)-polsv*coslon(ix)
  end do
! work 1 is u, work2 is v
  do j=1,nlon
     do i=1,nlat
        if(i /= ione .and. i /= nlat)then
           work1(i,j)=grid3(i-ione,j)
           work2(i,j)=grid1(i-ione,j)
        else if(i == ione)then
           work1(i,j)=grid3s(j)
           work2(i,j)=grid1s(j)
        else
           work1(i,j)=grid3n(j)
           work2(i,j)=grid1n(j)
        end if
     end do
  enddo

  return
  end subroutine stvp2uv


  subroutine uv2vordiv(work1,work2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    uv2vordiv compute vor/div from u/v
!   prgmmr: treadon          org: np23                date: 2005-03-21
!
! abstract: computes vorticity and divergence from u and v wind 
!           components using high-order compact differencing on 
!           a spherical grid.
!
! program history log:
!   2005-03-21  treadon
!   2006-02-02  derber  - modify code around poles (no difference)
!
!   input argument list:
!     work1  - array containing the u component
!     work2  - array containing the v component
!
!   output argument list:
!     work1  - array containing the vorticity
!     work2  - array containing the divergence
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$

  use constants, only: ione,zero,one
  use gridmod, only: iglobal,itotsub,ltosi,ltosj,ltosi_s,ltosj_s,&
       nlon,nlat
  implicit none

! Declare passed variables
  real(r_kind),dimension(itotsub),intent(inout) :: work1,work2

! Declare local variables  
  integer(i_kind) kk,ni1,ni2,lacox1,nxa,lacox2,lbcox1,nxh,ny,nya
  integer(i_kind) nbp,lcy,lbcoy2,iy,ix,lacoy1,lbcox2,lacoy2,lbcoy1
  real(r_kind) rnlon,div_n,div_s,vor_n,vor_s
  real(r_kind),dimension(nlat-2,nlon):: u,v,&
       grid_div,grid_vor,du_dlat,du_dlon,dv_dlat,dv_dlon

  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp

  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione

  do ix=1,nlon
     do iy=1,ny
        du_dlat(iy,ix)=zero
        du_dlon(iy,ix)=zero
        dv_dlat(iy,ix)=zero
        dv_dlon(iy,ix)=zero
        u(iy,ix)=zero
        v(iy,ix)=zero
        grid_div(iy,ix)=zero
        grid_vor(iy,ix)=zero
     end do
  end do


! Transfer u,v to local work arrays.  
  do kk=1,iglobal
     ni1=ltosi(kk); ni2=ltosj(kk)
     if(ni1 /= ione .and. ni1 /= nlat)then
        u(ni1-ione,ni2)=work1(kk)   ! work1 contains u on input
        v(ni1-ione,ni2)=work2(kk)   ! work2 contains v on input
     end if
  end do

! Compute x derivative of u:  du_dlon = du/dlon
  call xdcirdp(u,du_dlon,coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)

! Compute x derivative of v:  dv_dlon = dv/dlon
  call xdcirdp(v,dv_dlon,coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)

! Multiply u and v by cos(lat).  Note:  coef(lcy+iy) contains 1/cos(lat)
  do ix=1,nlon
     do iy=1,ny
        u(iy,ix)=u(iy,ix)/coef(lcy+iy)
        v(iy,ix)=v(iy,ix)/coef(lcy+iy)
     end do
  end do
  
! Compute y derivative of u:  du_dlat = du/dlat
  call ydsphdp(u,du_dlat,coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)

! Compute y derivative of v:  dv_dlat = dv/dlat
  call ydsphdp(v,dv_dlat,coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)

! Make corrections for convergence of meridians:
  do ix=1,nlon
     do iy=1,ny
        du_dlon(iy,ix)=du_dlon(iy,ix)*coef(lcy+iy)
        dv_dlon(iy,ix)=dv_dlon(iy,ix)*coef(lcy+iy)
        du_dlat(iy,ix)=du_dlat(iy,ix)*coef(lcy+iy)
        dv_dlat(iy,ix)=dv_dlat(iy,ix)*coef(lcy+iy)
     enddo
  enddo

! Combine derivatives to obtain vorticity and divergence
  do ix=1,nlon
     do iy=1,ny
        grid_div(iy,ix) = du_dlon(iy,ix) + dv_dlat(iy,ix)
        grid_vor(iy,ix) = dv_dlon(iy,ix) - du_dlat(iy,ix)
     end do
  end do

! Compute mean values to put in first and last row
  div_s=zero; div_n=zero
  vor_s=zero; vor_n=zero
  do ix=1,nlon
     div_s = div_s + grid_div( 1,ix)
     div_n = div_n + grid_div(ny,ix)
     vor_s = vor_s + grid_vor( 1,ix)
     vor_n = vor_n + grid_vor(ny,ix)
  end do
  rnlon = one/float(nlon)
  div_s = div_s*rnlon
  div_n = div_n*rnlon
  vor_s = vor_s*rnlon
  vor_n = vor_n*rnlon
  
! Transfer to output arrays
  do kk=1,itotsub
     ni1=ltosi_s(kk); ni2=ltosj_s(kk)
     if(ni1 /= ione .and. ni1 /= nlat)then
        work1(kk)=grid_vor(ni1-ione,ni2)
        work2(kk)=grid_div(ni1-ione,ni2)
     else if(ni1 == ione)then
        work1(kk)=vor_s
        work2(kk)=div_s
     else
        work1(kk)=vor_n
        work2(kk)=div_n
     end if
  enddo

  return
end subroutine uv2vordiv


  subroutine xdcirdp(p,q,aco1,bco1,aco2,bco2,nx,ny,noq,nxh)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    xdcirdp               compute x derivatives on sphere 
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  compute the x-derivatives of data with circle topology 
!            for rows using compact-differencing and add to existing
!            an field.		       
!									       
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!
!   input argument list:
!     p      - array of input data					       
!     aco1   - array containing the "a-coefficients", in the format of    
!              a banded l-d-u factorization, for the antisymmetric portion of   
!              the field to be differenced (initialized in cdcoef) 	    
!     bco1   - corresponding band-matrix of "b-coefficients"	   
!     aco2   - like aco1, but for the symmetric portion of the data	  
!     bco2   - like bco1, but for the symmetric portion of the data	 
!     nx     - number of points in a cyclic-row (x-direction) 	
!     ny     - number of parallel rows				
!     noq    - quarter of the order of differencing (1 implies 4th-order)
!     nxh    - one half of nx				       
!
!   output argument list:
!     q      - array of derivatives are added		   	       
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                     ,intent(in   ) :: nx,ny,noq,nxh
  real(r_kind),dimension(ny,nx)       ,intent(in   ) :: p
  real(r_kind),dimension(nxh,-noq:noq),intent(in   ) :: aco1,bco1,aco2,bco2
  real(r_kind),dimension(ny,nx)       ,intent(  out) :: q

! Declare local variables
  integer(i_kind) nxhp,ix,iy,nxp,ix1,ix2
  real(r_kind),dimension(ny,nx):: v1,v2

  nxhp=nxh+ione
  nxp=nx+ione

!  treat odd-symmetry component of input:
  do ix=1,nxh
     ix1=nxh+ix
     ix2=nxp-ix
     do iy=1,ny
        v1(iy,ix1)=p(iy,ix)-p(iy,ix2)
        v2(iy,ix )=p(iy,ix)+p(iy,nxp-ix)
     enddo
  enddo
  call xmulbv(bco1,v1(1,nxhp),v1,nxh,nxh,noq,noq,ny,nxh,nx,nx)
  call xbacbv(aco1,v1,nxh,noq,noq,ny,nxh,nx)

!  treat even-symmetry component of input:
  call xmulbv(bco2,v2,v2(1,nxhp),nxh,nxh,noq,noq,ny,nxh,nx,nx)
  call xbacbv(aco2,v2(1,nxhp),nxh,noq,noq,ny,nxh,nx)
  do ix=1,nxh
     ix1=nxp-ix
     ix2=nxh+ix
     do iy=1,ny
        q(iy,ix) =v1(iy,ix)+v2(iy,ix2)
        q(iy,ix1)=v1(iy,ix)-v2(iy,ix2)
     enddo
  enddo
  return
  end subroutine xdcirdp


  subroutine xmulbv(a,v1,v2,n1x,n2x,nbh1,nbh2,ny, na,nv1,nv2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    xmulbv multiplication of a banded matrix times x vectors
!   prgmmr: purser           org: np20                date: 1994-01-01
!
! abstract:  multiplication of a banded matrix times parallel x vectors     
!									       
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!
!   input argument list:
!     a      - matrix
!     v1     - array of input vectors
!     n1x    - number of rows assumed for a and for v2
!     n2x    - number of columns assumed for a and rows for v1
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     ny     - number of parallel x-vectors
!     na     - first fortran dimension of a
!     nv1    - first fortran dimension of v1
!     nv2    - first fortran dimension of v2
!
!   output argument list:
!     v2     - array of output vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione,zero
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: n1x,n2x,nbh1,nbh2,ny,na,nv1,nv2
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(ny,nv1)       ,intent(in   ) :: v1
  real(r_kind),dimension(ny,nv2)       ,intent(  out) :: v2

! Declare local variables
  logical odd
  integer(i_kind) ix,iy,jix,ix1,iy1

  odd=mod(ny,2)==ione
  do ix=1,n1x
     do iy=1,ny
        v2(iy,ix)=zero
     enddo
  enddo
  do jix=-nbh1,nbh2
     do ix=max(ione,ione-jix),min(n1x,n2x-jix)
        ix1=jix+ix
        do iy=1,ny-ione,2
           iy1=iy+ione
           v2(iy,ix )=v2(iy,ix )+a(ix,jix)*v1(iy,ix1)
           v2(iy1,ix)=v2(iy1,ix)+a(ix,jix)*v1(iy1,ix1)
        enddo
        if (odd) v2(ny,ix)=v2(ny,ix)+a(ix,jix)*v1(ny,ix1)
     enddo
  enddo
  return
  end subroutine xmulbv


  subroutine xbacbv(a,v,nx,nbh1,nbh2,ny,na,nv)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    xbacbv back-substitution step of parallel linear inversion
!   prgmmr: purser           org: np20                date:  1994-01-01
!
! abstract:  back-substitution step of parallel linear 
!            inversion involving banded matrix and x-vectors.
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     a      - encodes the (l)*(d**-1)*(u) factorization of the linear-system
!              matrix, as supplied by subroutine aldub or, if n=na, by ldub
!     v      - right-hand-side vectors
!     nx     - number of rows assumed for a and length of
!              x-vectors stored in v
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     ny     - number of parallel x-vectors inverted
!     na     - first fortran dimension of a
!     nv     - first (x-direction) fortran dimension of v
!
!   output argument list:
!     v      - solution vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: nx,nbh1,nbh2,ny,na,nv
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(ny,nv)        ,intent(inout) :: v

! Declare local variables
  integer(i_kind) jx,ix,iy,ix1

  do jx=1,nx
     do ix=jx+ione,min(nx,jx+nbh1)
        ix1=jx-ix
        do iy=1,ny
           v(iy,ix)=v(iy,ix)-a(ix,ix1)*v(iy,jx)
        enddo
     end do
     do iy=1,ny
        v(iy,jx)=a(jx,0)*v(iy,jx)
     end do
  end do
  do jx=nx,2,-1
     do ix=max(ione,jx-nbh2),jx-ione
        ix1=jx-ix
        do iy=1,ny
           v(iy,ix)=v(iy,ix)-a(ix,ix1)*v(iy,jx)
        enddo
     enddo
  end do

  return
  end subroutine xbacbv


  subroutine tstvp2uv(work1,work2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tstvp2uv                           adjoint of stvp2uv
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  adjoint of stvp2uv which computes uv from streamfunction/
!            velocity potential by calculating gradient of a scalar 
!            field using high-order compact differencing on a 
!            spherical grid.
!
! program history log:
!   1994-05-15  parrish,d. elimanate memory bank conflicts
!   1994-05-17  parrish,d. reverse order of longitude and latitude
!   2004-07-27  treadon - add only on use declarations; add intent in/out
!   2004-10-26  kleist - fix sign error
!   2008-06-05  safford - rm unused vars
!   2009-04-19  derber modified interface
!
!   input argument list:
!     work1  - array containing the adjoint u velocity 
!     work2  - array containing the adjoint v velocity
!
!   output argument list:
!     work1  - array containing the adjoint streamfunction 
!     work2  - array containing the adjoint velocity potential 
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use gridmod, only: sinlon,coslon,nlat,nlon
  use constants, only: ione,zero
  implicit none

! Declare passed scalars, arrays
  real(r_kind),dimension(nlat,nlon),intent(inout) :: work1,work2

! Declare local scalars,arrays
  integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
  integer(i_kind) lacoy2,lbcoy2,lcy,iy,ix,i,j
  real(r_kind) polsu,polsv,polnu,polnv
  real(r_kind),dimension(nlon):: grid3n,grid3s,grid1n,grid1s
  real(r_kind),dimension(nlat-2_i_kind,nlon):: a,b,grid2,grid3,grid1,grid4


  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione
  
  do j=1,nlon
     do i=1,nlat
        if(i /= ione .and. i /= nlat)then
           grid3(i-ione,j)=work1(i,j)
           grid1(i-ione,j)=work2(i,j)
        else if(i == ione)then
           grid3s(j)=work1(i,j)
           grid1s(j)=work2(i,j)
        else
           grid3n(j)=work1(i,j)
           grid1n(j)=work2(i,j)
        end if
     end do
  end do
  
  polnu=zero
  polsu=zero
  polnv=zero
  polsv=zero
  do ix=1,nlon
     polnu=polnu+grid3n(ix)*coslon(ix)-sinlon(ix)*grid1n(ix)
     polsu=polsu+grid3s(ix)*coslon(ix)+sinlon(ix)*grid1s(ix)
     polnv=polnv+grid3n(ix)*sinlon(ix)+coslon(ix)*grid1n(ix)
     polsv=polsv+grid3s(ix)*sinlon(ix)-coslon(ix)*grid1s(ix)
  end do
  polnu=polnu/float(nlon)
  polsu=polsu/float(nlon)
  polnv=polnv/float(nlon)
  polsv=polsv/float(nlon)
  
  do ix=1,nlon
     grid3(ny,ix)=grid3(ny,ix)+polnu*coslon(ix)+polnv*sinlon(ix)
     grid3(1,ix) =grid3(1,ix) +polsu*coslon(ix)+polsv*sinlon(ix)
     grid1(ny,ix)=grid1(ny,ix)-polnu*sinlon(ix)+polnv*coslon(ix)
     grid1(1,ix) =grid1(1,ix) +polsu*sinlon(ix)-polsv*coslon(ix)
  end do
  
  
!  make corrections for convergence of meridians:
  do ix=1,nlon
     do iy=1,ny
        grid4(iy,ix)=grid1(iy,ix)
        grid2(iy,ix)=-grid3(iy,ix)
        grid3(iy,ix)=grid3(iy,ix)*coef(lcy+iy)
        grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)
     end do
  end do

  call xdcirdp(grid3,b, &
       coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2), &
       nlon,ny,noq,nxh)

  call xdcirdp(grid1,a, &
       coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2), &
       nlon,ny,noq,nxh)

  call tydsphdp(a,grid2, &
       coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2), &
       nlon,ny,noq)

  call tydsphdp(b,grid4, &
       coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2), &
       nlon,ny,noq)

  do j=1,nlon
     do i=1,nlat
        if(i /= ione .and. i /= nlat)then
!          NOTE:  Adjoint of first derivative is its negative
           work1(i,j)=-a(i-ione,j)
           work2(i,j)=-b(i-ione,j)
        else
           work1(i,j)=zero
           work2(i,j)=zero
        end if
     end do
  end do
  
  return
  end subroutine tstvp2uv


  subroutine ydsphdp(p,q,aco1,bco1,aco2,bco2,nx,ny,noq)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    ydsphdp               compute y derivatives on sphere
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  compute the y-derivatives of data with spherical topology    
!  using compact-differencing and add to an existing field		    
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add only on use declarations; add intent in/out
!
!   input argument list:
!     p      - array of input data					  
!     q      - array to which derivatives are added			   
!     aco1   - array containing the "a-coefficients", in the format of 
!              a banded l-d-u factorization, for the antisymmetric portion of 
!              the field to be differenced (initialized in cdcoef) 	   
!     bco1   - corresponding band-matrix of "b-coefficients"	  
!     aco2   - like aco1, but for the symmetric portion of the data	 
!     bco2   - like bco1, but for the symmetric portion of the data	
!     nx     - number of longitudes (x-direction), an even number.	
!     ny     - number of latitude points (y-direction)	
!     noq    - quarter of the order of differencing (1 implies 4th-order) 
!
!   output argument list:
!     q      - array to which derivatives are added			   
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                    ,intent(in   ) :: nx,ny,noq
  real(r_kind),dimension(ny,-noq:noq),intent(in   ) :: aco1,bco1,aco2,bco2
  real(r_kind),dimension(ny,nx)      ,intent(in   ) :: p
  real(r_kind),dimension(ny,nx)      ,intent(  out) :: q

! Declare local variables
  integer(i_kind) nxh,nxhp,ix,iy,ix1
  real(r_kind),dimension(ny,nx):: v1,v2

  nxh=nx/2
  nxhp=nxh+ione

!  treat odd-symmetry component of input:
  do ix=1,nxh
     ix1=nxh+ix
     do iy=1,ny
        v1(iy,ix1)=p(iy,ix)-p(iy,ix1)
        v2(iy,ix)= p(iy,ix)+p(iy,ix1)
     enddo
  enddo
  call ymulbv(bco1,v1(1,nxhp),v1,ny,ny,noq,noq,nxh,ny,nx,nx)
  call ybacbv(aco1,v1,ny,noq,noq,nxh,ny,nx)

!  treat even-symmetry component of input:
  call ymulbv(bco2,v2,v2(1,nxhp),ny,ny,noq,noq,nxh,ny,nx,nx)
  call ybacbv(aco2,v2(1,nxhp),ny,noq,noq,nxh,ny,nx)
  do ix=1,nxh
     ix1=nxh+ix
     do iy=1,ny
        q(iy,ix )=v2(iy,ix1)+v1(iy,ix)
        q(iy,ix1)=v2(iy,ix1)-v1(iy,ix)
     enddo
  enddo
  return
  end subroutine ydsphdp


  subroutine ymulbv(a,v1,v2, n1y,n2y,nbh1,nbh2,nx, na,nv1,nv2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    ymulbv multiplication of a banded matrix times parallel y vects
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  multiplication of a banded matrix times parallel y-vectors.
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add only on use declarations; add intent in/out
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     a      - matrix
!     v1     - array of input vectors
!     n1y    - number of rows assumed for a and for v2
!     n2y    - number of columns assumed for a and rows for v1
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     nx     - length of each of the parallel y-vectors
!     na     - first fortran dimension of a
!     nv1    - first fortran dimension of v1
!     nv2    - first fortran dimension of v2
!
!   output argument list:
!     v2     - array of output vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$

  use constants, only: ione,zero
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: n1y,n2y,nbh1,nbh2,nx,na,nv1,nv2
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(n2y,nv1)      ,intent(in   ) :: v1
  real(r_kind),dimension(n1y,nv2)      ,intent(  out) :: v2

! Declare local variables
  integer(i_kind) ix,iy,jiy

  do ix=1,nx
     do iy=1,n1y
        v2(iy,ix)=zero
     enddo
  enddo
  do ix=1,nx
     do jiy=-nbh1,nbh2
        do iy=max(ione,ione-jiy),min(n1y,n2y-jiy)
           v2(iy,ix)=v2(iy,ix)+a(iy,jiy)*v1(jiy+iy,ix)
        enddo
     end do
  end do
  return
  end subroutine ymulbv


  subroutine ybacbv(a,v,ny,nbh1,nbh2,nx,na,nv)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    ybacbv back-substitution step of parallel linear inversion
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  back-substitution step of parallel linear inversion involving
!  banded matrix and y-vectors.
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     v      - right-hand-side vectors
!     a      - encodes the (l)*(d**-1)*(u) factorization of the linear-system
!              matrix, as supplied by subroutine aldub or, if n=na, by ldub
!     ny     - number of rows assumed for a and length of
!              y-vectors stored in v
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     nx     - number of parallel y-vectors inverted
!     na     - first fortran dimension of a
!     nv     - first (x-direction) fortran dimension of v
!
!   output argument list:
!     v      - solution vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: ny,nbh1,nbh2,nx,na,nv
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(ny,nv)        ,intent(inout) :: v

! Declare local variables
  logical odd
  integer(i_kind) jy,iy,ix,ix1

  odd = mod(nx,2)==ione
  do ix=1,nx-ione,2
     ix1=ix+ione
     do jy=1,ny
        do iy=jy+ione,min(ny,jy+nbh1)
           v(iy,ix) =v(iy,ix) -a(iy,jy-iy)*v(jy,ix)
           v(iy,ix1)=v(iy,ix1)-a(iy,jy-iy)*v(jy,ix1)
        enddo
        v(jy,ix) =a(jy,0)*v(jy,ix)
        v(jy,ix1)=a(jy,0)*v(jy,ix1)
     end do
     do jy=ny,2,-1
        do iy=max(ione,jy-nbh2),jy-ione
           v(iy,ix) =v(iy,ix) -a(iy,jy-iy)*v(jy,ix)
           v(iy,ix1)=v(iy,ix1)-a(iy,jy-iy)*v(jy,ix1)
        enddo
     enddo
  end do
  if (odd) then
     ix=nx
     do jy=1,ny
        do iy=jy+ione,min(ny,jy+nbh1)
           v(iy,ix)=v(iy,ix)-a(iy,jy-iy)*v(jy,ix)
        enddo
        v(jy,ix)=a(jy,0)*v(jy,ix)
     end do
     do jy=ny,2,-1
        do iy=max(ione,jy-nbh2),jy-ione
           v(iy,ix)=v(iy,ix)-a(iy,jy-iy)*v(jy,ix)
        enddo
     enddo
  endif
     
  return
  end subroutine ybacbv


  subroutine tydsphdp(p,q,aco1,bco1,aco2,bco2,nx,ny,noq)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tydsphdp                           adjoint of ydsphdp
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  adjoint of ydsphdp which computes the y-derivatives of
!            data with spherical topology using compact-differencing
!            and add to an existing field		    
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!
!   input argument list:
!     q      - array of input adjoint data  
!     aco1   - array containing the "a-coefficients", in the format of 
!              a banded l-d-u factorization, for the antisymmetric portion of 
!              the field to be differenced (initialized in cdcoef) 	   
!     bco1   - corresponding band-matrix of "b-coefficients"	  
!     aco2   - like aco1, but for the symmetric portion of the data	 
!     bco2   - like bco1, but for the symmetric portion of the data	
!     nx     - number of longitudes (x-direction), an even number.	
!     ny     - number of latitude points (y-direction)	
!     noq    - quarter of the order of differencing (1 implies 4th-order) 
!
!   output argument list:
!     p      - array to which adjoint derivatives are added  
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                    ,intent(in   ) :: nx,ny,noq
  real(r_kind),dimension(ny,-noq:noq),intent(in   ) :: aco1,bco1,aco2,bco2
  real(r_kind),dimension(ny,nx)      ,intent(in   ) :: q
  real(r_kind),dimension(ny,nx)      ,intent(  out) :: p

! Declare local variables
  integer(i_kind) nxh,nxhp,ix,iy,ix1
  real(r_kind),dimension(ny,nx):: v1,v2

  nxh=nx/2
  nxhp=nxh+ione
  do ix=1,nxh
     ix1=nxh+ix
     do iy=1,ny
        v1(iy,ix1)=q(iy,ix)+q(iy,ix1)
        v2(iy,ix)=q(iy,ix)-q(iy,ix1)
     enddo
  enddo
  
  call ybacvb(v1(1,nxhp),aco2,ny,noq,noq,nxh,nx,ny)
  call ymulvb(v1(1,nxhp),bco2,v1,ny,ny,noq,noq,nxh,nx,ny,nx)
  
  call ybacvb(v2,aco1,ny,noq,noq,nxh,nx,ny)
  call ymulvb(v2,bco1,v2(1,nxhp),ny,ny,noq,noq,nxh,nx,ny,nx)
  do ix=1,nxh
     ix1=nxh+ix
     do iy=1,ny
        p(iy,ix )=p(iy,ix )-v1(iy,ix)-v2(iy,ix1)
        p(iy,ix1)=p(iy,ix1)-v1(iy,ix)+v2(iy,ix1)
     enddo
  enddo
  
  return
  end subroutine tydsphdp


  subroutine ybacvb(v,a,ny,nbh1,nbh2,nx,nv,na)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    ybacvb back-substitution step of parallel linear inversion
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  back-substitution step of parallel linear inversion involving
!            banded matrix and row-y-vectors.
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     v      - right-hand-side vectors
!     a      - encodes the (l)*(d**-1)*(u) factorization of the linear-system
!              matrix, as supplied by subroutine aldub or, if n=na, by ldub
!     ny     - number of rows assumed for a and length of
!              y-vectors stored in v
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     nx     - number of parallel y-vectors inverted
!     na     - first fortran dimension of a
!     nv     - first (x-direction) fortran dimension of v
!
!   output argument list:
!     v      - solution vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: ny,nbh1,nbh2,nx,nv,na
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(ny,nv)        ,intent(inout) :: v

! Declare local variables  
  logical odd
  integer(i_kind) iy,jy,ix,ix1

  odd = mod(nx,2)==ione

  do ix=1,nx-ione,2
     ix1=ix+ione
     do iy=1,ny
        do jy=iy+ione,min(ny,iy+nbh2)
           v(jy,ix) =v(jy,ix) -v(iy,ix) *a(iy,jy-iy)
           v(jy,ix1)=v(jy,ix1)-v(iy,ix1)*a(iy,jy-iy)
        enddo
        v(iy,ix) =v(iy,ix) *a(iy,0)
        v(iy,ix1)=v(iy,ix1)*a(iy,0)
     enddo

     do iy=ny,2,-1
        do jy=max(ione,iy-nbh1),iy-ione
           v(jy,ix) =v(jy,ix) -v(iy,ix) *a(iy,jy-iy)
           v(jy,ix1)=v(jy,ix1)-v(iy,ix1)*a(iy,jy-iy)
        enddo
     enddo
  end do

  if (odd) then
     ix=nx
     do iy=1,ny
        do jy=iy+ione,min(ny,iy+nbh2)
           v(jy,ix) =v(jy,ix) -v(iy,ix) *a(iy,jy-iy)
        enddo
        v(iy,ix) =v(iy,ix) *a(iy,0)
     end do
     do iy=ny,2,-1
        do jy=max(ione,iy-nbh1),iy-ione
           v(jy,ix) =v(jy,ix) -v(iy,ix) *a(iy,jy-iy)
        enddo
     end do
  endif
  return
  end subroutine ybacvb


  subroutine ymulvb(v1,a,v2,n1y,n2y,nbh1,nbh2,nx,nv1,na,nv2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    ymulvb multiplication of y-vectors times banded matrix 
!   prgmmr: purser           org: np20               date:  1994-01-01
!
! abstract:  multiplication of y-vectors times banded matrix 
!
! program history log:
!   1994-05-12  parrish,d. elimanate memory bank conflicts
!   2004-07-27  treadon - add intent in/out
!
!   input argument list:
!     a      - matrix
!     v1     - array of input row-vectors
!     n1y    - number of rows assumed for a and for v1
!     n2y    - number of columns assumed for a and columns for v2
!     nbh1   - left half-bandwidth of fortran array a
!     nbh2   - right half-bandwidth of fortran array a
!     nx     - length of each of the parallel y-vectors
!     na     - first fortran dimension of a
!     nv1    - first fortran dimension of v1
!     nv2    - first fortran dimension of v2
!
!   output argument list:
!     v2     - array of output vectors
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp
!$$$

  use constants, only: ione,zero
  implicit none

! Delcare passed variables
  integer(i_kind)                      ,intent(in   ) :: n1y,n2y,nbh1,nbh2,nx,na,nv1,nv2
  real(r_kind),dimension(na,-nbh1:nbh2),intent(in   ) :: a
  real(r_kind),dimension(n1y,nv1)      ,intent(in   ) :: v1
  real(r_kind),dimension(n2y,nv2)      ,intent(  out) :: v2

! Declare local variables
  integer(i_kind) ix,iy,jiy,jy
  real(r_kind) aij

  do ix=1,nx
     do iy=1,n2y
        v2(iy,ix)=zero
     enddo
  enddo

  do ix=1,nx
     do jiy=-nbh1,nbh2
        do iy=max(ione,ione-jiy),min(n1y,n2y-jiy)
           jy=jiy+iy
           aij=a(iy,jiy)
           v2(jy,ix)=v2(jy,ix)+v1(iy,ix)*aij
        enddo
     enddo
  end do
  return
  end subroutine ymulvb


  subroutine inisph(r,yor,tau,nx,ny)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    inisph          init coefs for compact diff on sphere
!   prgmmr: purser, r.j.     org: np20                date: 1994-01-01
!
! abstract:  This routine initializes coefficients for high-order 
!            compact differencing on a spherical grid.
!
! program history log:
!   1994-01-01  purser
!   2004-06-21  treadon - update documentation
!   2004-07-28  treadon - add only to module use, add intent in/out
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     r   - radius of the sphere
!     yor - array of the increasing grid latitudes in radians
!     tau - array of quadrature weights associated with yor
!     nx  - (even) number of grid longitudes
!     ny  - number of grid latitudes
!
!   output argument list:
!     none
!
!   Remarks:  
!     This routine initializes array coef which is in module berror.
!     coef is an array of size 3*ny+4*(2*noq+1)*(ny+nx/2) containing 
!     the coefficients for high-order compact differencing
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero,half,one,two,pi
  use gridmod, only: nlat
  implicit none

! Declare passed variables
  integer(i_kind)                  ,intent(in   ) :: nx,ny
  real(r_kind)                     ,intent(in   ) :: r
  real(r_kind),dimension(nlat-ione),intent(in   ) :: tau,yor
  
! Declare local variables
  integer(i_kind) nxh,nbp,nya,nxa,lbcox1,lacox1,ltaui,lbcox2
  integer(i_kind) lacoy1,lacox2,lbcoy1,lcy,lacoy2,lbcoy2,i,ix,ltau,iy
  real(r_kind) pih,pi2onx,ri
  real(r_kind),dimension(max(nx/2,ny+2_i_kind)+16_i_kind+52*(noq+5_i_kind)+32*(noq+5_i_kind)**2):: w

! Set parameters for calls to subsequent routines  
  nxh=nx/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione
  ltau  =lcy   +ny
  ltaui =ltau  +ny
  coef = zero


! Check for error conditions.  If found, write message to standard
! out and stop program execution.
  if (2*nxh /= nx) then
     write(6,*)'INISPH:  ***ERROR***'
     write(6,'(" number of longitudes,'',i4,'' specified in ")') nx
     write(6,'(" passed through parameter list of subroutine inisph")')
     write(6,'(" is an odd number. Please use an EVEN number.")')
     call stop2(61)
  endif
  do iy=1,ny
     if (yor(iy)<=(-pi) .or. yor(iy)>=pi) then
        write(6,*)'INISPH:  ***ERROR***'
        write(6,'(" grid-latitude number ",i4," passed through")') iy
        write(6,'(" parameter list of subroutine inisph lies outside")')
        write(6,'(" the range of (-pi/2 , pi/2)")')
        call stop2(62)
     endif
  enddo

! Load coefficient array
  ri=one/r
  pih=pi/two
  pi2onx=pi/float(nxh)
  do ix=1,nxh
     coef(lacoy1+ix-ione)=(float(ix)-half)*pi2onx
  enddo

  call cdcoef(nxh,noq,zero,pi,coef(lacoy1),w&
       ,coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2)&
       ,nxh,nxh,nxh,nxh)
  do i=0,nxa-ione
     coef(lbcox1+i)=coef(lbcox1+i)*ri
     coef(lbcox2+i)=coef(lbcox2+i)*ri
  enddo
  
  call cdcoef(ny,noq,-pih,pih,yor,w&
       ,coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2)&
       ,ny,ny,ny,ny)
  do i=0,nya-ione
     coef(lbcoy1+i)=coef(lbcoy1+i)*ri
     coef(lbcoy2+i)=coef(lbcoy2+i)*ri
  enddo
  
  do iy=1,ny
     coef(lcy+iy)=one/cos(yor(iy))
     coef(ltau+iy)=tau(iy)
     coef(ltaui+iy)=one/tau(iy)
  enddo

  end subroutine inisph


  subroutine cdcoef(nh,noq,zlim1,zlim2,z,work,aco1,bco1,aco2,bco2,na1,nb1,na2,nb2)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    cdcoef              compute differencing coeffciients
!   prgmmr: purser, r.j.     org: np20                date: 1994-01-01
!
! abstract:  This routine computes the coefficients, in band-matrix 
!            form, of a compact differencing operator for 
!            symmetrically arranged cyclic data.
!
! program history log:
!   1994-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28  treadon - add only to module use, add intent in/out
!
!   input argument list:
!     nh    - number data in one of the symmetric halves of the cycle
!     noq   - quarter of the intended order of accuracy
!     zlim1 - coordinate of first reflection-point
!     zlim2 - coordinate of the second reflection-point
!     z     - array of coordinates, strictly in (zlim1,zlim2) for one
!             symmetric half of the cycle. the coordinate of the point
!             preceeding z(1) is 2*zlim1-z(1) etc., while the coordinate
!             of the point succeeding z(nh) in the cycle is 2*zlim2-z(nh) etc.
!     work  - work-space array of size 2*(8+nh+26*noq+16*noq**2)
!     na1   - first dimension of aco1
!     nb1   - first dimension of bco1
!     na2   - first dimension of aco2
!     nb2   - first dimension of bco2
!
!   output argument list:
!     aco1 - array containing the "a-coefficients", in the format of
!            a banded l-d-u factorization, for the antisymmetric portion
!            of the field to be differenced
!     bco1 - corresponding band-matrix of "b-coefficients"
!     aco2 - like aco1, but for the symmetric portion of the data
!     bco2 - like bco1, but for the symmetric portion of the data
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero,two
  implicit none

! Declare passed variables  
  integer(i_kind)                     ,intent(in   ) :: nh,noq,na1,nb1,na2,nb2
  real(r_kind)                        ,intent(in   ) :: zlim1,zlim2
  real(r_kind),dimension(*)           ,intent(in   ) :: z
  real(r_kind),dimension(ione-noq:*)  ,intent(inout) :: work
  real(r_kind),dimension(na1,-noq:noq),intent(  out) :: aco1
  real(r_kind),dimension(nb1,-noq:noq),intent(  out) :: bco1
  real(r_kind),dimension(na2,-noq:noq),intent(  out) :: aco2
  real(r_kind),dimension(nb2,-noq:noq),intent(  out) :: bco2

! Declare local variables
  integer(i_kind) kw,kb,js,ir,i,n,j,ka,nohp

! Initialize output arrays to zero  
  n=nh*2
  do i=1,nh
     work(i)=z(i)
     do j=-noq,noq
        aco1(i,j)=zero
        bco1(i,j)=zero
        aco2(i,j)=zero
        bco2(i,j)=zero
     enddo
  enddo

! Load work array
  do i=1,noq
     work(ione-i)=two*zlim1-work(i)
     work(nh+i  )=two*zlim2-work(nh+ione-i)
  enddo

! Set local parameters
  nohp=noq*2+ione
  ka=nh+noq+ione
  kb=ka+nohp
  kw=kb+nohp


! Compute coefficients
  do i=1,nh
     call dfcd(work(i-noq),work(i-noq),work(i),nohp,nohp&
          ,work(ka),work(kb),work(kw))
     do j=i-noq,i+noq
        if(j<ione)then
           ir=-ione
           js=ione-j-i
        elseif(j>nh)then
           js=n+ione-j-i
           ir=-ione
        else
           js=j-i
           ir=ione
        endif
        aco1(i,js)=aco1(i,js)+	 work(ka+noq+j-i)
        bco1(i,js)=bco1(i,js)+ir*work(kb+noq+j-i)/two
        aco2(i,js)=aco2(i,js)+ir*work(ka+noq+j-i)
        bco2(i,js)=bco2(i,js)+	 work(kb+noq+j-i)/two
     enddo
  enddo
  call aldub(aco1,nh,noq,noq,na1)
  call aldub(aco2,nh,noq,noq,na2)
  return
  end subroutine cdcoef


  subroutine dfcd(za,zb,z0,na,nb,a,b,work)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    dfcd        compute coefs for compact/lagrange schemes
!                            for differencing or quadrature
!   prgmmr: purser, r.j.     org: np20                date: 1994-01-01
!
! abstract:  This routine computes coefficients for compact or 
!            lagrange schemes for differencing or quadrature.  A 
!            description of the routine functionality for quadrature
!            and differencing follows in the remarks section.
!
! program history log:
!   1994-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28 treadon - add only to module use, add intent in/out
!
!   input argument list:
!      The meaning of arguments varies as described above based
!      on the type of coefficients being computed.
!
!   output argument list:
!      The meaning of arguments varies as described above based
!      on the type of coefficients being computed.
!
! remarks:
!
!  Quadrature:
!   Input:
!     let Z0 be the coordinate of the nominated "target" point,
!            (e.g., the midpoint of the target interval)
!     ZA are the coordinates of the NA source template points.
!     ZB are the coordinates of the NB target template points -
!     NB=2 for a Lagrange scheme, otherwise NB>2.
!   Output:
!     A is the vector of NA A-coefficients, A(1), .. A(NA)
!     B is the vector of NB B-coefficients, B(1), ...B(NB)
!     (For a Lagrange scheme B(1) = -B(2) = 1/("delta sigma".)
!   
!   WORK is an array of work-space used for the intermediate
!   calculations - it contains nothing of interest on input or output.
!   It must be given a size of at least 2*(NA+NB)*(NA+NB+1) in the
!   routine that calls this one (it is the same as in DFCO except now
!   using double precision)
!
!   Differencing:
!   The only changes from the case of quadrature are that:
!     Z0 is the coordinate of the particular target point, which is
!        no longer arbitrary;
!     ZA are coordinates of TARGET template point(s);
!     ZB are coordinates of SOURCE template points;
!     A is the vector of NA A-coefficients;
!     B is the vector of NB (=ND) D-coefficients
!     (For a Lagrange scheme NA=1 and, trivially, A(1) = 1. )
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero,one
  implicit none

! Declare passed variables
  integer(i_kind)          ,intent(in   ) :: na,nb
  real(r_kind)             ,intent(in   ) :: z0
  real(r_kind),dimension(*),intent(in   ) :: za,zb
  real(r_kind),dimension(*),intent(  out) :: work,a,b

! Declare local variables  
  integer(i_kind) nc,ncs,ncsp,j,iw,i
  real(r_kind) p,z
  
  nc=na+nb
  ncs=nc*nc
  ncsp=ncs+ione
  do j=1,na
     iw=ione+(j-ione)*nc
     work(iw)=one
     work(iw+ione)=zero
     work(iw+2_i_kind)=one
  enddo
  do j=1,nb
     iw=ione+(j+na-ione)*nc
     work(iw)=zero
     work(iw+ione)=one
  enddo
  do j=1,na
     z=za(j)-z0
     p=one
     do i=4,nc
        p=p*z
        work(i+(j-ione)*nc)=p*(i-2_i_kind)
     enddo
  enddo
  do j=1,nb
     z=zb(j)-z0
     p=one
     do i=3,nc
        p=p*z
        work(i+(j+na-ione)*nc)=-p
     enddo
  enddo
  work(ncsp)=one
  do i=2,nc
     work(ncs+i)=zero
  enddo
  
! Find the following routine qlinvmv (a linear equation solver) amongst
! all the other basic matrix routines (here, the double precision
! version is used).
  call dlinvmm(work,work(ncsp),nc,ione,nc,nc)
  do i=1,na
     a(i)=work(ncs+i)
  enddo
  do i=1,nb
     b(i)=work(ncs+na+i)
  enddo
  return
  end subroutine dfcd


  subroutine aldub(a,n,nbh1,nbh2,na)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    aldub                               ldu decomposition
!   prgmmr: purser, r.j.     org: np20                date: 1994-01-01
!
! abstract:  This routine computes the (L)*(D**-1)*(U) decomposition 
!            of asymmetric band-matrix compact differencing on 
!            a spherical grid.
!
! program history log:
!   1994-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28 treadon - add only to module use, add intent in/out
!
!   input argument list:
!     "a"   - asymmetric band matrix
!      n    - number of rows assumed for A and for V
!      nbh1 - left half-bandwidth of fortran array A
!      nbh2 - right half-bandwidth of fortran array A
!      na   - first fortran dimension of A
!
!   output argument list:
!     "a"   - contains the (L)*(D**-1)*(U) factorization of the 
!             input matrix, where
!             (L) is lower triangular with unit main diagonal
!             (D) is a diagonal matrix
!             (U) is upper triangular with unit main diagonal
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero,one
  implicit none

! Declare passed variables
  integer(i_kind)                      ,intent(in   ) :: n,nbh1,nbh2,na
  real(r_kind),dimension(na,-nbh1:nbh2),intent(inout) :: a

! Declare local variables
  integer(i_kind) j,jp,i,k,imost,jmost
  real(r_kind) ajj,aij,ajji

  do j=1,n
     imost=min(n,j+nbh1)
     jmost=min(n,j+nbh2)
     jp=j+ione
     ajj=a(j,0)
     if(ajj==zero)then
        write(6,*)'ALDUB:  ***ERROR***'
        write(6,'("  FAILURE:  matrix requires pivoting or is singular")')
        call stop2(63)
     endif
     ajji=one/ajj
     a(j,0)=ajji
     do i=jp,imost
        aij=ajji*a(i,j-i)
        a(i,j-i)=aij
        do k=jp,jmost
           a(i,k-i)=a(i,k-i)-aij*a(j,k-j)
        enddo
     enddo
     do k=jp,jmost
        a(j,k-j)=ajji*a(j,k-j)
     enddo
  enddo
  return
  end subroutine aldub


  subroutine dlinvmm(a,b,m,mm,na,nb)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    dlinvmm                         invert linear systems
!   prgmmr: purser, r.j.     org: np20                date: 1993-01-01
!
! abstract:  This routine inverts linear systems sharing the same square
!            system matrix in DOUBLE PRECISION.
!
! program history log:
!   1993-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28  treadon - add only to module use, add intent in/out
!
!   input argument list:
!     "a"   - square system matrix
!     "b"   - right-hands-sides
!      m    - degree of (active part of) b and a
!      mm   - number of right-hand-side vectors (active columns of b)
!      na   - first fortran dimension of a
!      nb   - first fortran dimension of b
!
!   output argument list:
!     "a"   - L-D-U factorization of input matrix "a"
!     "b"   - matrix solution of vectors
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  implicit none

! Declare passed variables
  integer(i_kind)             ,intent(in   ) :: m,mm,na,nb
  real(r_kind),dimension(na,*),intent(inout) :: a
  real(r_kind),dimension(nb,*),intent(inout) :: b  

! Declare local parameters
  integer(i_kind),parameter:: nn = 500_i_kind

! Declare local variables
  integer(i_kind),dimension(nn):: ipiv
  real(r_kind) d

  call dlufm(a,ipiv,d,m,na)
  call dlubmm(a,b,ipiv,m,mm,na,nb)
  return
  end subroutine dlinvmm


  subroutine dlufm(a,ipiv,d,m,na)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    dlufm                       perform l-u decomposition
!   prgmmr: purser, r.j.     org: np20                date: 1993-01-01
!
! abstract:  This routine performs l-u decomposition of square matrix
!            "a" in place with partial pivoting in DOUBLE PRECISION.
!
! program history log:
!   1993-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28  treadon - add only to module use, add intent in/out
!
!   input argument list:
!     "a"   - square matrix to be factorized
!      m    - degree of (active part of) a
!      na   - first fortran dimension of a
!
!   output argument list:
!     "a"   - L-U factorization of input matrix "a"
!     ipiv  - array encoding the pivoting sequence
!     d     - indicator for possible sign change of determinant
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero,one
  implicit none

! Declare passed variables
  integer(i_kind)             ,intent(in   ) :: m,na
  integer(i_kind),dimension(*),intent(  out) :: ipiv
  real(r_kind)                ,intent(  out) :: d
  real(r_kind),dimension(na,*),intent(inout) :: a

! Declare local variables
  integer(i_kind) j,jp,ibig,jm,i,k
  real(r_kind) ajj,aij,ajji,t,abig,aa

  d=one
  ipiv(m)=m
  do j=1,m-ione
     jp=j+ione
     abig=abs(a(j,j))
     ibig=j
     do i=jp,m
        aa=abs(a(i,j))
        if(aa>abig)then
           ibig=i
           abig=aa
        endif
     enddo
!  swap rows, recording changed sign of determinant
     ipiv(j)=ibig
     if(ibig/=j)then
        d=-d
        do k=1,m
           t=a(j,k)
           a(j,k)=a(ibig,k)
           a(ibig,k)=t
        enddo
     endif
     ajj=a(j,j)
     if(ajj==zero)then
        jm=j-ione
        write(6,*)'DLUFM:  ***ERROR***'
        write(6,'("DLUFM:  failure due to singular matrix,r, rank=",i3)') jm
        call stop2(64)
     endif
     ajji=one/ajj
     do i=jp,m
        aij=ajji*a(i,j)
        a(i,j)=aij
        do k=jp,m
           a(i,k)=a(i,k)-aij*a(j,k)
        enddo
     enddo
  enddo
  return
  end subroutine dlufm


  subroutine dlubmm(a,b,ipiv,m,mm,na,nb)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    dlubmm                                  invert matrix
!   prgmmr: purser, r.j.     org: np20                date: 1993-01-01
!
! abstract:  This routine inverts matrix "a"
!
! program history log:
!   1993-01-01 purser
!   2004-06-21 treadon - update documentation
!   2004-07-28  treadon - add only to module use, add intent in/out
!
!   input argument list:
!     "a"   - square matrix to be factorized
!      m    - degree of (active part of) a
!      mm   - number of columns (active part of) b
!      na   - first fortran dimension of a
!      nb   - first fortran dimension of b
!     ipiv  - array encoding the pivoting sequence
!
!   output argument list:
!     "b"   - matrix solution of vectors
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione
  implicit none

! Declare passed variables
  integer(i_kind)             ,intent(in   ) :: m,mm,na,nb
  integer(i_kind),dimension(*),intent(in   ) :: ipiv
  real(r_kind),dimension(na,*),intent(in   ) :: a
  real(r_kind),dimension(nb,*),intent(  out) :: b

! Declare local variables  
  integer(i_kind) k,i,l,j
  real(r_kind) s

  do k=1,mm !loop over columns of b
     do i=1,m
        l=ipiv(i)
        s=b(l,k)
        b(l,k)=b(i,k)
        do j=1,i-ione
           s=s-a(i,j)*b(j,k)
        enddo
        b(i,k)=s
     enddo
     do i=m,1,-1
        s=b(i,k)
        do j=i+ione,m
           s=s-a(i,j)*b(j,k)
        enddo
        b(i,k)=s/a(i,i)
     enddo
  enddo
  return
  end subroutine dlubmm


  subroutine compact_dlon(b,dbdx,vector)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    compact_dlon   compact derivative in longitude
!   prgmmr: parrish          org: np23                date: 2005-05-16
!
! abstract:  Use high-order compact differencing on a spherical grid
!            to compute derivative in longitude.
!
! program history log:
!   2005-05-16  parrish
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     "b"    - array containing the scalar field
!     vector - if true, then b is one component of a vector field and dbdx
!                 is singular at poles, so output at poles set to zero.
!
!   output argument list:
!     dbdx  - array containing the eastward component of (1/(a*cos(lat)))db/dlon
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero
  use gridmod, only: nlon,nlat,sinlon,coslon
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(in   ) :: b
  logical                          ,intent(in   ) :: vector

  real(r_kind),dimension(nlat,nlon),intent(  out) :: dbdx

  integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
  integer(i_kind) lbcoy2,lacoy2,iy,ix,i,j,lcy
  real(r_kind),dimension(nlat-2_i_kind,nlon):: work3,grid3
  real(r_kind),dimension(nlon):: grid3n,grid3s
  real(r_kind) polnu,polnv,polsu,polsv


! Set parameters for calls to subsequent routines
  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione


! Initialize output arrays to zero
  do j=1,nlon
     do i=1,nlat
        dbdx(i,j)=zero
     end do
  end do

! Transfer scalar input field to work array.
! Zero other work arrays.
  do j=1,nlon
     do i=1,ny
        work3(i,j) = b(i+ione,j)
        grid3(i,j) = zero
     end do
  end do


! Compute x (east-west) derivatives on sphere
  call xdcirdp(work3,grid3, &
       coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)

! Make corrections for convergence of meridians:
  do ix=1,nlon
     do iy=1,ny
        grid3(iy,ix)=grid3(iy,ix)*coef(lcy+iy)
     end do
  end do

  if(.not.vector) then
     polnu=zero
     polnv=zero
     polsu=zero
     polsv=zero
     do ix=1,nlon
        polnu=polnu+grid3(ny,ix)*coslon(ix)
        polnv=polnv+grid3(ny,ix)*sinlon(ix)
        polsu=polsu+grid3(1 ,ix)*coslon(ix)
        polsv=polsv+grid3(1 ,ix)*sinlon(ix)
     end do
     polnu=polnu/float(nlon)
     polnv=polnv/float(nlon)
     polsu=polsu/float(nlon)
     polsv=polsv/float(nlon)
     do ix=1,nlon
        grid3n(ix)= polnu*coslon(ix)+polnv*sinlon(ix)
        grid3s(ix)= polsu*coslon(ix)+polsv*sinlon(ix)
     end do
  else
     do ix=1,nlon
        grid3n(ix)= zero
        grid3s(ix)= zero
     end do
  end if

! Load result into output array
  do j=1,nlon
     dbdx(1,j)=grid3s(j)
     dbdx(nlat,j)=grid3n(j)
     do i=1,ny
        dbdx(i+ione,j) = grid3(i,j)
     end do
  end do
  
  return
  end subroutine compact_dlon


  subroutine tcompact_dlon(b,dbdx,vector)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tcompact_dlon  adjoint of compact_dlon
!   prgmmr: parrish          org: np23                date: 2005-05-16
!
! abstract:  adjoint of compact_dlon
!
! program history log:
!   2005-05-16  parrish
!   2005-07-01  kleist, bug fix
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     "b"    - array containing existing contents to be accumulated to
!     dbdx  - array containing the eastward component of (1/(a*cos(lat)))db/dlon
!     vector - if true, then b is one component of a vector field and dbdx is
!                undefined at poles.
!
!   output argument list:
!     "b"    - array after adding contribution from adjoint of dbdx
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero
  use gridmod, only: nlon,nlat,sinlon,coslon
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(inout) :: b
  real(r_kind),dimension(nlat,nlon),intent(in   ) :: dbdx
  logical                          ,intent(in   ) :: vector

  integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
  integer(i_kind) lbcoy2,lacoy2,iy,ix,i,j,lcy
  real(r_kind),dimension(nlat-2_i_kind,nlon):: work3,grid3
  real(r_kind),dimension(nlon):: grid3n,grid3s
  real(r_kind) polnu,polnv,polsu,polsv


! Set parameters for calls to subsequent routines
  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione

  do j=1,nlon
     grid3s(j)=dbdx(1,j)
     grid3n(j)=dbdx(nlat,j)
     do i=1,ny
        grid3(i,j)=dbdx(i+ione,j) 
     end do
  end do
  if(.not.vector) then
     polnu=zero
     polnv=zero
     polsu=zero
     polsv=zero
     do ix=1,nlon
        polnu=polnu+coslon(ix)*grid3n(ix)
        polnv=polnv+sinlon(ix)*grid3n(ix)
        polsu=polsu+coslon(ix)*grid3s(ix)
        polsv=polsv+sinlon(ix)*grid3s(ix)
     end do
     polnu=polnu/float(nlon)
     polnv=polnv/float(nlon)
     polsu=polsu/float(nlon)
     polsv=polsv/float(nlon)
     do ix=1,nlon
        grid3(ny,ix)=grid3(ny,ix)+coslon(ix)*polnu+sinlon(ix)*polnv
        grid3(1 ,ix)=grid3(1 ,ix)+coslon(ix)*polsu+sinlon(ix)*polsv
     end do
  else
     do ix=1,nlon
        grid3n(ix)= zero
        grid3s(ix)= zero
     end do
  end if

! Make corrections for convergence of meridians:
  do ix=1,nlon
     do iy=1,ny
        grid3(iy,ix)=grid3(iy,ix)*coef(lcy+iy)
     end do
  end do

! adjoint of X (east-west) derivatives on sphere
  call xdcirdp(grid3,work3, &
       coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
       nlon,ny,noq,nxh)

! Transfer scalar input field to work array.
! Zero other work arrays.
  do j=1,nlon
     do i=1,ny
!       NOTE:  Adjoint of first derivative is its negative
        b(i+ione,j)=b(i+ione,j)-work3(i,j)
     end do
  end do
  
  return
  end subroutine tcompact_dlon


  subroutine compact_dlat(b,dbdy,vector)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    compact_dlat   compact derivative in latitude
!   prgmmr: parrish          org: np23                date: 2005-05-16
!
! abstract:  Use high-order compact differencing on a spherical grid
!            to compute derivative in latitude.
!
! program history log:
!   2005-05-16  parrish
!   2005-07-01  kleist, bug fix
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     "b"    - array containing the scalar field
!     vector - if true, then b is one component of a vector field and dbdy
!                 is singular at poles, so output at poles set to zero.
!
!   output argument list:
!     dbdy  - if vector true, then =  (1/(a*cos(lat)))d(b*cos(lat))/dlat
!           -      otherwise,      =  (1/a)(db/dlat)
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero
  use gridmod, only: nlon,nlat,sinlon,coslon
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(in   ) :: b
  logical                          ,intent(in   ) :: vector

  real(r_kind),dimension(nlat,nlon),intent(  out) :: dbdy

  integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
  integer(i_kind) lbcoy2,lacoy2,iy,ix,i,j,lcy
  real(r_kind),dimension(nlat-2_i_kind,nlon):: work2,grid4
  real(r_kind),dimension(nlon)::grid4n,grid4s
  real(r_kind) polnu,polnv,polsu,polsv


! Set parameters for calls to subsequent routines
  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione


! Initialize output arrays to zero
  do j=1,nlon
     do i=1,nlat
        dbdy(i,j)=zero
     end do
  end do

! Transfer scalar input field to work array.
! Zero other work arrays.
  do j=1,nlon
     do i=1,ny
        work2(i,j) = b(i+ione,j)
        grid4(i,j) = zero
     end do
  end do

  if(vector) then
!    multiply by cos(lat) ( 1/coef(lcy+iy) )
     do ix=1,nlon
        do iy=1,ny
           work2(iy,ix)=work2(iy,ix)/coef(lcy+iy)
        enddo
     enddo
  end if

! Compute y (south-north) derivatives on sphere
  call ydsphdp(work2,grid4, &
       coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)

  if(vector) then
!    divide by cos(lat)
     do ix=1,nlon
        do iy=1,ny
           grid4(iy,ix)=grid4(iy,ix)*coef(lcy+iy)
        enddo
     enddo
     do ix=1,nlon
        grid4n(ix)= zero
        grid4s(ix)= zero
     end do
  else
     polnu=zero
     polnv=zero
     polsu=zero
     polsv=zero
     do ix=1,nlon
        polnu=polnu-grid4(ny,ix)*sinlon(ix)
        polnv=polnv+grid4(ny,ix)*coslon(ix)
        polsu=polsu+grid4(1 ,ix)*sinlon(ix)
        polsv=polsv-grid4(1 ,ix)*coslon(ix)
     end do
     polnu=polnu/float(nlon)
     polnv=polnv/float(nlon)
     polsu=polsu/float(nlon)
     polsv=polsv/float(nlon)
     do ix=1,nlon
        grid4n(ix)=-polnu*sinlon(ix)+polnv*coslon(ix)
        grid4s(ix)= polsu*sinlon(ix)-polsv*coslon(ix)
     end do
  end if

! Load result into output array
  do j=1,nlon
     dbdy(1,j)=grid4s(j)
     dbdy(nlat,j)=grid4n(j)
     do i=1,ny
        dbdy(i+ione,j) = grid4(i,j)
     end do
  end do
  
  return
  end subroutine compact_dlat


  subroutine tcompact_dlat(b,dbdy,vector)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tcompact_dlat   adjoint of compact_dlat
!   prgmmr: parrish          org: np23                date: 2005-05-16
!
! abstract:  adjoint of compact_dlat
!
! program history log:
!   2005-05-16  parrish
!   2005-07-01  kleist, bug and sign fixes
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     "b"    - array containing existing contents to be accumulated to
!     dbdy  - if vector true, then =  (1/(a*cos(lat)))d(b*cos(lat))/dlat
!           -      otherwise,      =  (1/a)(db/dlat)
!     vector - if true, then b is one component of a vector field and dbdy is
!                undefined at poles.
!
!   output argument list:
!     "b"    - array after adding contribution from adjoint of dbdy
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use constants, only: ione,zero
  use gridmod, only: nlon,nlat,sinlon,coslon
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(inout) :: b
  real(r_kind),dimension(nlat,nlon),intent(in   ) :: dbdy
  logical                          ,intent(in   ) :: vector

  integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
  integer(i_kind) lbcoy2,lacoy2,iy,ix,i,j,lcy
  real(r_kind),dimension(nlat-2_i_kind,nlon):: work2,grid4
  real(r_kind),dimension(nlon)::grid4n,grid4s
  real(r_kind) polnu,polnv,polsu,polsv


! Set parameters for calls to subsequent routines
  ny=nlat-2_i_kind
  nxh=nlon/2
  nbp=2*noq+ione
  nya=ny*nbp
  nxa=nxh*nbp
  
  lacox1=ione
  lbcox1=lacox1+nxa
  lacox2=lbcox1+nxa
  lbcox2=lacox2+nxa
  lacoy1=lbcox2+nxa
  lbcoy1=lacoy1+nya
  lacoy2=lbcoy1+nya
  lbcoy2=lacoy2+nya
  lcy   =lbcoy2+nya-ione

  do j=1,nlon
     grid4s(j)=dbdy(1,j)
     grid4n(j)=dbdy(nlat,j)
     do i=1,ny
        grid4(i,j)=dbdy(i+ione,j) 
     end do
  end do
  if(vector) then
     do ix=1,nlon
        grid4n(ix)= zero
        grid4s(ix)= zero
     end do
!    divide by cos(lat)
     do ix=1,nlon
        do iy=1,ny
           grid4(iy,ix)=grid4(iy,ix)*coef(lcy+iy)
        enddo
     enddo
  else
     polnu=zero
     polnv=zero
     polsu=zero
     polsv=zero
     do ix=1,nlon
        polnu=polnu-sinlon(ix)*grid4n(ix)
        polnv=polnv+coslon(ix)*grid4n(ix)
        polsu=polsu+sinlon(ix)*grid4s(ix)
        polsv=polsv-coslon(ix)*grid4s(ix)
     end do
     polnu=polnu/float(nlon)
     polnv=polnv/float(nlon)
     polsu=polsu/float(nlon)
     polsv=polsv/float(nlon)
     do ix=1,nlon
        grid4(ny,ix)=grid4(ny,ix)-sinlon(ix)*polnu+coslon(ix)*polnv
        grid4(1 ,ix)=grid4(1 ,ix)+sinlon(ix)*polsu-coslon(ix)*polsv
     end do
  end if

! adjoint of y derivative on sphere
  work2=zero
  call tydsphdp(work2,grid4, &
       coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
       nlon,ny,noq)

  if(vector) then
!    multiply by cos(lat) ( 1/coef(lcy+iy) )
     do ix=1,nlon
        do iy=1,ny
           work2(iy,ix)=work2(iy,ix)/coef(lcy+iy)
        enddo
     enddo
  end if
! accumulate to output field

  do j=1,nlon
     do i=1,ny
!       NOTE:  Adjoint of first derivative is its negative
        b(i+ione,j)=b(i+ione,j)-work2(i,j)   !????/check this in particular
     end do
  end do
  
  return
  end subroutine tcompact_dlat


  subroutine compact_delsqr(b,delsqrb)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    compact_delsqr compact laplacian
!   prgmmr: parrish          org: np23                date: 2006-02-13
!
! abstract:  Call high-order compact differencing routines to get
!            laplacian of input field.
!
! program history log:
!   2006-02-13  parrish
!
!   input argument list:
!     "b"    - array containing the scalar field
!
!   output argument list:
!     delsqrb  -  (1/(a*cos(lat)))*d((1/a)(db/dlat)*cos(lat))/dlat
!                      + (1/((a*cos(lat))**2)*d(db/dlon)/dlon
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use gridmod, only: nlon,nlat
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(in   ) :: b
  real(r_kind),dimension(nlat,nlon),intent(  out) :: delsqrb

  real(r_kind),dimension(nlat,nlon):: bx,by,bxx,byy
  integer(i_kind) i,j

  call compact_dlon(b,bx,.false.)
  call compact_dlon(bx,bxx,.true.)
  call compact_dlat(b,by,.false.)
  call compact_dlat(by,byy,.true.)

  do j=1,nlon
     do i=1,nlat
        delsqrb(i,j)=bxx(i,j)+byy(i,j)
     end do
  end do

  return
  end subroutine compact_delsqr


  subroutine tcompact_delsqr(b,delsqrb)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    adjoint of compact_delsqr
!   prgmmr: parrish          org: np23                date: 2006-02-13
!
! abstract:  Call high-order compact differencing routines to get
!            laplacian of input field.
!
! program history log:
!   2006-02-13  parrish
!
!   input argument list:
!     delsqrb  -  (1/(a*cos(lat)))*d((1/a)(db/dlat)*cos(lat))/dlat
!                      + (1/((a*cos(lat))**2)*d(db/dlon)/dlon
!     b        -  contains previous contents that result of this routine
!                   are added on to.
!   output argument list:
!     "b"    - array containing accumulated results
!
!  note:  b not initialized to zero here, because result is accumulated to
!        previous contents of b
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use gridmod, only: nlon,nlat
  use constants, only: zero
  implicit none

  real(r_kind),dimension(nlat,nlon),intent(inout) :: b
  real(r_kind),dimension(nlat,nlon),intent(in   ) :: delsqrb

  real(r_kind),dimension(nlat,nlon):: bx,by,bxx,byy

  integer(i_kind) i,j


  do j=1,nlon
     do i=1,nlat
        bxx(i,j)=zero
        byy(i,j)=zero
        bx(i,j)=zero
        by(i,j)=zero
     end do
  end do
  do j=1,nlon
     do i=1,nlat
        bxx(i,j)=bxx(i,j)+delsqrb(i,j)
        byy(i,j)=byy(i,j)+delsqrb(i,j)
     end do
  end do
  call tcompact_dlat(by,byy,.true.)
  call tcompact_dlat(b,by,.false.)
  call tcompact_dlon(bx,bxx,.true.)
  call tcompact_dlon(b,bx,.false.)

  return
  end subroutine tcompact_delsqr


  subroutine compact_grad(a,dadx,dady)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    compact_grad                     compute grad(scalar)
!   prgmmr: purser, r.j.     org: np20                date: 1994-01-01
!
! abstract:  This routine computes the gradient of a scalar field
!            using high-order compact differencing on a spherical
!            grid.
!
! program history log:
!   1994-01-01  purser
!   1994-05-12  parrish - eliminate memory bank conflicts
!   2004-06-16  treadon - update documentation
!   2008-06-05  safford - rm unused vars
!
!   input argument list:
!     "a"   - array containing the scalar field
!
!   output argument list:
!     dadx  - array containing the eastward component of gradient
!     dady  - array containing the northward component of gradient
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use constants, only: ione,zero
    use gridmod, only: nlon, nlat
    implicit none

    real(r_kind),dimension(nlat,nlon),intent(in   ) :: a
    real(r_kind),dimension(nlat,nlon),intent(  out) :: dadx,dady

    integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
    integer(i_kind) lbcoy2,lacoy2,lcy,iy,ix,i,j
    real(r_kind),dimension(nlat-2_i_kind,nlon):: work1,grid1,grid2

! Set parameters for calls to subsequent routines
    ny=nlat-2_i_kind
    nxh=nlon/2
    nbp=2*noq+ione
    nya=ny*nbp
    nxa=nxh*nbp

    lacox1=ione
    lbcox1=lacox1+nxa
    lacox2=lbcox1+nxa
    lbcox2=lacox2+nxa
    lacoy1=lbcox2+nxa
    lbcoy1=lacoy1+nya
    lacoy2=lbcoy1+nya
    lbcoy2=lacoy2+nya
    lcy   =lbcoy2+nya-ione

! Initialize output arrays to zero
    do j=1,nlon
       do i=1,nlat
          dadx(i,j)=zero
          dady(i,j)=zero
       end do
    end do

! Transfer scalar input field to work array.
! Zero other work arrays.
    do j=1,nlon
       do i=1,ny
          work1(i,j) = a(i+ione,j)
          grid1(i,j)=zero
          grid2(i,j)=zero
       end do
    end do

! Compute x (east-west) derivatives on sphere
    call xdcirdp(work1,grid1, &
         coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
         nlon,ny,noq,nxh)

! Compute y (south-north) derivatives on sphere
    call ydsphdp(work1,grid2, &
         coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
         nlon,ny,noq)

! Make corrections for convergence of meridians:
    do ix=1,nlon
       do iy=1,ny
          grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)
       end do
    end do

! Load results into ouptut arrays
    do j=1,nlon
       do i=1,ny
          dadx(i+ione,j) = grid1(i,j)
          dady(i+ione,j) = grid2(i,j)
       end do
    end do

    return
  end subroutine compact_grad


  subroutine compact_grad_ad(a,dadx,dady)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    compact_grad_ad
!
!   prgrmmr:
!
! abstract:
!
! program history log:
!   2008-06-05  safford -- add subprogram doc block, rm unused vars
!
!   input argument list:
!     dadx,dady
!
!   output argument list:
!     a
!
! attributes:
!   language:  f90
!   machine:   ibm RS/6000 SP
!
!$$$ end documentation block

    use constants, only: ione,zero
    use gridmod, only: nlon, nlat
    implicit none

    real(r_kind),dimension(nlat,nlon),intent(in   ) :: dadx,dady
    real(r_kind),dimension(nlat,nlon),intent(  out) :: a

    integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
    integer(i_kind) lbcoy2,lacoy2,lcy,iy,ix,i,j
    real(r_kind),dimension(nlat-2_i_kind,nlon):: work1,work2,grid1,grid2

! Set parameters for calls to subsequent routines
    ny=nlat-2_i_kind
    nxh=nlon/2
    nbp=2*noq+ione
    nya=ny*nbp
    nxa=nxh*nbp

    lacox1=ione
    lbcox1=lacox1+nxa
    lacox2=lbcox1+nxa
    lbcox2=lacox2+nxa
    lacoy1=lbcox2+nxa
    lbcoy1=lacoy1+nya
    lacoy2=lbcoy1+nya
    lbcoy2=lacoy2+nya
    lcy   =lbcoy2+nya-ione

! Initialize output arrays to zero
    do j=1,nlon
       do i=1,ny
          grid1(i,j) = dadx(i+ione,j)
          grid2(i,j) = dady(i+ione,j)
          work1(i,j)=zero
          work2(i,j)=zero
       end do
    end do

!  MAKE CORRECTIONS FOR CONVERGENCE OF MERIDIANS:
    do ix=1,nlon
       do iy=1,ny
          grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)
       end do
    end do

! Compute y (south-north) derivatives on sphere
    call tydsphdp(work2,grid2, &
         coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
         nlon,ny,noq)

! Compute x (east-west) derivatives on sphere
    call xdcirdp(grid1,work1, &
         coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
         nlon,ny,noq,nxh)

! Load results into output arrays
    a=zero
    do j=1,nlon
       do i=1,ny
          a(i+ione,j) = -work1(i,j)-work2(i,j)
       end do
    end do

    return
  end subroutine compact_grad_ad


  subroutine compact_div(uin,vin,div)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    compact_div
!
!   prgrmmr:
!
! abstract:
!
! program history log:
!   2008-06-05  safford -- add subprogram doc block, rm unused vars
!
!   input argument list:
!     uin,vin
!
!   output argument list:
!     div
!
! attributes:
!   language:  f90
!   machine:   ibm RS/6000 SP
!
!$$$ end documentation block

    use constants, only: ione,zero
    use gridmod, only: nlon,nlat
    implicit none

    real(r_kind),dimension(nlat,nlon),intent(in   ) :: uin,vin
    real(r_kind),dimension(nlat,nlon),intent(  out) :: div

    integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
    integer(i_kind) lbcoy2,lacoy2,lcy,iy,ix,i,j
    real(r_kind),dimension(nlat-2_i_kind,nlon):: work1,work2,grid1,grid2

! Set parameters for calls to subsequent routines
    ny=nlat-2_i_kind
    nxh=nlon/2
    nbp=2*noq+ione
    nya=ny*nbp
    nxa=nxh*nbp

    lacox1=ione
    lbcox1=lacox1+nxa
    lacox2=lbcox1+nxa
    lbcox2=lacox2+nxa
    lacoy1=lbcox2+nxa
    lbcoy1=lacoy1+nya
    lacoy2=lbcoy1+nya
    lbcoy2=lacoy2+nya
    lcy   =lbcoy2+nya-ione

! Initialize output arrays to zero
    do j=1,nlon
       do i=1,nlat
          div(i,j)=zero
       end do
    end do

! Transfer scalar input field to work array.
! Zero other work arrays.
    do j=1,nlon
       do i=1,ny
          work1(i,j) = uin(i+ione,j)
          work2(i,j) = vin(i+ione,j)
          grid1(i,j)=zero
          grid2(i,j)=zero
       end do
    end do

! Compute x (east-west) derivatives on sphere of u-wind
    call xdcirdp(work1,grid1, &
         coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
         nlon,ny,noq,nxh)

! Make corrections for convergence of meridians:
    do ix=1,nlon
       do iy=1,ny
          grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)
       end do
    end do

!  first multiply by cos(lat)
    do ix=1,nlon
       do iy=1,ny
          work2(iy,ix)=work2(iy,ix)/coef(lcy+iy)
       end do
    end do

! Compute y (south-north) derivatives on sphere of v-wnd
    call ydsphdp(work2,grid2, &
         coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
         nlon,ny,noq)

! Make corrections for convergence of meridians:
    do ix=1,nlon
       do iy=1,ny
          grid2(iy,ix)=grid2(iy,ix)*coef(lcy+iy)
       end do
    end do

! Load results into ouptut arrays
    do j=1,nlon
       do i=1,ny
          div(i+ione,j)=grid1(i,j)+grid2(i,j)
       end do
    end do

    return
  end subroutine compact_div


  subroutine compact_div_ad(ux,vy,ddiv)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    compact_div_ad
!
!   prgrmmr:
!
! abstract:
!
! program history log:
!   2008-06-05  safford -- add subprogram doc block, rm unused vars
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language:  f90
!   machine:   ibm RS/6000 SP
!
!$$$ end documentation block

    use constants, only: ione,zero
    use gridmod, only: nlat,nlon
    implicit none
    
    real(r_kind),dimension(nlat,nlon),intent(  out) :: ux,vy
    real(r_kind),dimension(nlat,nlon),intent(in   ) :: ddiv

    integer(i_kind) ny,nxh,nbp,nya,nxa,lacox1,lbcox1,lacox2,lbcox2,lacoy1,lbcoy1
    integer(i_kind) lbcoy2,lacoy2,lcy,iy,ix,i,j
    real(r_kind),dimension(nlat-2_i_kind,nlon):: work1,work2,grid1,grid2

! Set parameters for calls to subsequent routines
    ny=nlat-2_i_kind
    nxh=nlon/2
    nbp=2*noq+ione
    nya=ny*nbp
    nxa=nxh*nbp

    lacox1=ione
    lbcox1=lacox1+nxa
    lacox2=lbcox1+nxa
    lbcox2=lacox2+nxa
    lacoy1=lbcox2+nxa
    lbcoy1=lacoy1+nya
    lacoy2=lbcoy1+nya
    lbcoy2=lacoy2+nya
    lcy   =lbcoy2+nya-ione

! Transfer scalar input field to work array.
! Zero other work arrays.
    do j=1,nlon
       do i=1,ny
          grid1(i,j) = ddiv(i+ione,j)
          grid2(i,j) = ddiv(i+ione,j)
          work1(i,j) = zero
          work2(i,j) = zero
       end do
    end do


! Make corrections for convergence of meridians:
    do ix=1,nlon
       do iy=1,ny
          grid2(iy,ix)=grid2(iy,ix)*coef(lcy+iy)
       end do
    end do

    call tydsphdp(work2,grid2, &
         coef(lacoy1),coef(lbcoy1),coef(lacoy2),coef(lbcoy2),&
         nlon,ny,noq)

!  now multiply by cos(lat)
    do ix=1,nlon
       do iy=1,ny
          work2(iy,ix)=work2(iy,ix)/coef(lcy+iy)
       end do
    end do


! Make corrections for convergence of meridians:
    do ix=1,nlon
       do iy=1,ny
          grid1(iy,ix)=grid1(iy,ix)*coef(lcy+iy)
       end do
    end do

! Compute x (east-west) derivatives on sphere of u-wind
    call xdcirdp(grid1,work1, &
         coef(lacox1),coef(lbcox1),coef(lacox2),coef(lbcox2),&
         nlon,ny,noq,nxh)

    ux=zero
    vy=zero
! Load results into ouptut arrays
    do j=1,nlon
       do i=1,ny
          ux(i+ione,j) = -work1(i,j)
          vy(i+ione,j) = -work2(i,j)
       end do
    end do

    return
  end subroutine compact_div_ad

end module compact_diffs
