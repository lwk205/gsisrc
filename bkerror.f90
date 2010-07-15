subroutine bkerror(gradx,grady)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    bkerror  apply background error covariance            
!   prgmmr: wu               org: np22                date: 1999-12-07
!
! abstract: grid transform, apply recursive filters on conformal/Cartesian 
!            grids back to Gaussian grid.
!
! program history log:
!   2003-12-18  derber, j. bring hoper and htoper into background error calcs.
!   2004-05-15  treadon - move slndt,sst,sicet=0 up from htoper to this routine
!   2004-07-28  treadon - add only to module use, add intent in/out
!   2004-08-27  kleist - background error covariance placed in single routine
!   2004-10-26  kleist - u,v removed from vector
!   2005-01-22  parrish - add module balmod to access balance and tbalance
!   2005-03-30  treadon - add more comments to periodic block
!   2006-11-30  todling - add fpsproj as arg to (t)balance routine(s)
!   2007-04-13  tremolet - use control vectors
!   2007-10-01  todling  - add timer
!   2008-12-29  todling - update interface to strong_bk/bk_ad
!   2009-04-13  derber - move strong_bk into balance
!   2010-03-01  zhu    - change bkgcov interface for generalized control variables
!                      - make changes with iterfaces of sub2grid and grid2sub
!   2010-04-28  todling - update to use gsi_bundle
!   2010-05-31  todling - revisit check on pointers
!
!   input argument list:
!     gradx    - input field  
!
!   output
!     grady    - background structure * gradx 
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block
  use kinds, only: r_kind,i_kind
  use berror, only: varprd,fpsproj
  use balmod, only: balance,tbalance
  use gsi_4dvar, only: nsubwin, lsqrtb
  use gridmod, only: lat2,lon2,nlat,nlon,nnnn1o,periodic,latlon11
  use jfunc, only: nsclen,npclen
  use constants, only:  zero
  use control_vectors
  use timermod, only: timer_ini,timer_fnl
  use gsi_bundlemod, only: gsi_bundlegetpointer
  implicit none

! Declare passed variables
  type(control_vector),intent(inout) :: gradx
  type(control_vector),intent(inout) :: grady

! Declare local variables
  integer(i_kind) i,j,iflg,ii
  integer(i_kind) i_t,i_p,i_st,i_vp
  integer(i_kind) ipnts(4),istatus
  real(r_kind),dimension(nlat,nlon,nnnn1o):: work
  real(r_kind),dimension(lat2,lon2):: slndt,sicet
  real(r_kind),pointer,dimension(:,:)  :: p_sst
  logical dobal

  if (lsqrtb) then
     write(6,*)'bkerror: not for use with lsqrtb'
     call stop2(317)
  end if

! Initialize timer
  call timer_ini('bkerror')

! If dealing with periodic (sub)domain, gather full domain grids,
! account for periodicity, and redistribute to subdomains.  This
! only needs to be done when running with a single mpi task and
! then only for array gradx.
  if (periodic) then
     iflg=2
     do j=1,lon2
        do i=1,lat2
           slndt(i,j)=zero
           sicet(i,j)=zero
        end do
     end do
     do ii=1,nsubwin
        call gsi_bundlegetpointer ( gradx%step(ii),(/'sst'/),ipnts,istatus )
        if (istatus==0) then
           p_sst => gradx%step(ii)%r2(ipnts(1))%q
        else
           p_sst => NULL() 
        end if
        call sub2grid(work,gradx%step(ii),p_sst,slndt,sicet,iflg)
        call grid2sub(work,gradx%step(ii),p_sst,slndt,sicet)
     end do
  endif

! Put things in grady first since operations change input variables
  grady=gradx

! Only need to get pointer for ii=1 - all other are the same
  call gsi_bundlegetpointer ( grady%step(1), (/'t ','sf','vp','ps'/), &
                              ipnts, istatus )
  i_t  = ipnts(1)
  i_st = ipnts(2)
  i_vp = ipnts(3)
  i_p  = ipnts(4)
  dobal = i_t>0.and.i_p>0.and.i_st>0.and.i_vp>0

! Loop on control steps
  do ii=1,nsubwin

!    Transpose of balance equation
     if(dobal) &
     call tbalance(grady%step(ii)%r3(i_t )%q,grady%step(ii)%r2(i_p )%q, &
                   grady%step(ii)%r3(i_st)%q,grady%step(ii)%r3(i_vp)%q,fpsproj)

!    Apply variances, as well as vertical & horizontal parts of background error
     call bkgcov(grady%step(ii),nnnn1o)

!    Balance equation
     if(dobal) &
     call balance(grady%step(ii)%r3(i_t )%q,grady%step(ii)%r2(i_p )%q, &
                  grady%step(ii)%r3(i_st)%q,grady%step(ii)%r3(i_vp)%q,fpsproj)

  end do

! Take care of background error for bias correction terms
  do i=1,nsclen
     grady%predr(i)=grady%predr(i)*varprd(i)
  end do
  do i=1,npclen
     grady%predp(i)=grady%predp(i)*varprd(nsclen+i)
  end do

! Finalize timer
  call timer_fnl('bkerror')

  return
end subroutine bkerror
