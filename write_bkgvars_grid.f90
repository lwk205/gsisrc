subroutine write_bkgvars_grid(a,b,c,d,mype)
!$$$  subroutine documentation block
!
! subprogram:    write_bkgvars_grid
!
!   prgrmmr:
!
! abstract:  modified routine to write out files to compare spectral computation
!            of horizontal derivatives with the derivatives that are being
!            carried around for the dynamical balance constraint
!
! program history log:
!   2008-03-27  safford -- add subprogram doc block, rm unused vars and uses
!
!   input argument list:
!     mype     - mpi task id
!     a        -
!     b        -
!     c        -
!     d        -
!
!   output argument list:
!
! attributes:
!   language:  f90
!   machine:
!
!$$$
  use kinds, only: r_kind,i_kind,r_single
  use constants, only: izero
  use gridmod, only: nlat,nlon,nsig,lat2,lon2
  implicit none

  integer(i_kind)                       ,intent(in   ) :: mype

  real(r_kind),dimension(lat2,lon2,nsig),intent(in   ) :: a,b,c
  real(r_kind),dimension(lat2,lon2)     ,intent(in   ) :: d

  character(255):: grdfile

  real(r_kind),dimension(nlat,nlon,nsig):: ag,bg,cg
  real(r_kind),dimension(nlat,nlon):: dg

  real(r_single),dimension(nlon,nlat,nsig):: a4,b4,c4
  real(r_single),dimension(nlon,nlat):: d4

  integer(i_kind) ncfggg,iret,i,j,k

! gather stuff to processor 0
  do k=1,nsig
     call gather_stuff2(a(1,1,k),ag(1,1,k),mype,izero)
     call gather_stuff2(b(1,1,k),bg(1,1,k),mype,izero)
     call gather_stuff2(c(1,1,k),cg(1,1,k),mype,izero)
  end do
  call gather_stuff2(d,dg,mype,izero)

  if (mype==izero) then
     write(6,*) 'WRITE OUT NEW VARIANCES'
! load single precision arrays
     do k=1,nsig
        do j=1,nlon
           do i=1,nlat
              a4(j,i,k)=ag(i,j,k)
              b4(j,i,k)=bg(i,j,k)
              c4(j,i,k)=cg(i,j,k)
           end do
        end do
     end do
     do j=1,nlon
        do i=1,nlat
           d4(j,i)=dg(i,j)
        end do
     end do

! Create byte-addressable binary file for grads
     grdfile='bkgvar_rewgt.grd'
     ncfggg=len_trim(grdfile)
     call baopenwt(22_i_kind,grdfile(1:ncfggg),iret)
     call wryte(22_i_kind,4*nlat*nlon*nsig,a4)
     call wryte(22_i_kind,4*nlat*nlon*nsig,b4)
     call wryte(22_i_kind,4*nlat*nlon*nsig,c4)
     call wryte(22_i_kind,4*nlat*nlon,d4)
     call baclose(22_i_kind,iret)
  end if
   
  return
end subroutine write_bkgvars_grid

subroutine write_bkgvars2_grid
!$$$  subroutine documentation block
!
! subprogram:    write_bkgvars2_grid
!
!   prgrmmr:
!
! abstract:  modified routine to write out files to compare spectral computation
!            of horizontal derivatives with the derivatives that are being
!            carried around for the dynamical balance constraint
!
! program history log:
!   2008-03-27  safford -- add subprogram doc block, rm unused vars and uses
!   2010-06-18  todling -- generalized to show all variances; create ctl
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language:  f90
!   machine:
!
!$$$
  use kinds, only: r_kind,i_kind,r_single
  use mpimod, only: mype
  use constants, only: zero,r1000,one_tenth
  use gridmod, only: nlat,nlon,nsig,lat2,lon2
  use gridmod, only: ak5,bk5,ck5,tref5,idvc5,&
         regional,wrf_nmm_regional,nems_nmmb_regional,wrf_mass_regional,pt_ll,&
         eta2_ll,pdtop_ll,eta1_ll,twodvar_regional,idsl5
  use control_vectors, only: nc3d,nc2d,mvars
  use control_vectors, only: cvars3d,cvars2d,cvarsmd
  use berror, only: dssv,dssvs
  use file_utility, only : get_lun
  implicit none

  character(255):: grdfile

  real(r_kind),dimension(nlat,nlon,nsig,nc3d):: ag
  real(r_kind),dimension(nlat,nlon,nc2d+mvars):: dg

  real(r_single),dimension(nlon,nlat,nsig,nc3d):: a4
  real(r_single),dimension(nlon,nlat,nc2d+mvars):: d4

  real(r_kind)   ,dimension(nsig+1)::prs
  integer(i_kind) ncfggg,iret,lu,i,j,k,n

! gather stuff to processor 0
  do n=1,nc3d
     do k=1,nsig
        call gather_stuff2(dssv(1,1,k,n),ag(1,1,k,n),mype,0)
     end do
  end do
  do n=1,nc2d
     call gather_stuff2(dssvs(1,1,n),dg(1,1,n),mype,0)
  end do
  do n=1,mvars
     call gather_stuff2(dssvs(1,1,nc2d+n),dg(1,1,nc2d+n),mype,0)
  end do

! get some reference-like pressure levels
  do k=1,nsig+1
     if(regional) then
        if (wrf_nmm_regional.or.nems_nmmb_regional) &
           prs(k)=one_tenth* &
                  (eta1_ll(k)*pdtop_ll + &
                   eta2_ll(k)*(r1000-pdtop_ll-pt_ll) + &
                   pt_ll)
        if (wrf_mass_regional .or. twodvar_regional) &
           prs(k)=one_tenth*(eta1_ll(k)*(r1000-pt_ll) + pt_ll)
     else
        if (idvc5==1 .or. idvc5==2) then
           prs(k)=ak5(k)+(bk5(k)*r1000)
        else if (idvc5==3) then
           if (k==1) then
              prs(k)=r1000
           else if (k==nsig+1) then
              prs(k)=zero
           else
              prs(k)=ak5(k)+(bk5(k)*r1000)! +(ck5(k)*trk)
           end if
        end if
     endif
  enddo

  if (mype==0) then
     write(6,*) 'WRITE OUT NEW VARIANCES'
!    Load single precision arrays
     do n=1,nc3d
        do k=1,nsig
           do j=1,nlon
              do i=1,nlat
                 a4(j,i,k,n)=ag(i,j,k,n)
              end do
           end do
        end do
     end do
     do n=1,nc2d+mvars
        do j=1,nlon
           do i=1,nlat
              d4(j,i,n)=dg(i,j,n)
           end do
        end do
     end do

!    Create byte-addressable binary file for grads
     grdfile='bkgvar_smooth.grd'
     ncfggg=len_trim(grdfile)
     lu=get_lun()
     call baopenwt(lu,grdfile(1:ncfggg),iret)
!    Loop over 3d-variances
     do n=1,nc3d
        call wryte(lu,4*nlat*nlon*nsig,a4(1,1,1,n))
     enddo
!    Loop over 2d-variances
     do n=1,nc2d+mvars
        call wryte(lu,4*nlat*nlon,d4(1,1,n))
     enddo
     call baclose(lu,iret)

!    Now create corresponding grads table file
     lu=get_lun()
     open(lu,file='bkgvar_smooth.ctl',form='formatted')
     write(lu,'(2a)') 'DSET  ^', trim(grdfile)
     write(lu,'(2a)') 'TITLE ', 'gsi berror variances'
     write(lu,'(a,2x,e13.6)') 'UNDEF', 1.E+15 ! any other preference for this?
     write(lu,'(a,2x,i4,2x,a,2x,f5.1,2x,f9.6)') 'XDEF',nlon, 'LINEAR',   0.0, 360./nlon
     write(lu,'(a,2x,i4,2x,a,2x,f5.1,2x,f9.6)') 'YDEF',nlat, 'LINEAR', -90.0, 180./(nlat-1.)
     write(lu,'(a,2x,i4,2x,a,100(1x,f10.5))')      'ZDEF',nsig, 'LEVELS', prs
     write(lu,'(a,2x,i4,2x,a)')   'TDEF', 1, 'LINEAR 12:00Z04JUL1776 6hr' ! any date suffices
     write(lu,'(a,2x,i4)')        'VARS',nc3d+nc2d+mvars
     do n=1,nc3d
        write(lu,'(a,1x,2(i4,1x),a)') trim(cvars3d(n)),nsig,0,trim(cvars3d(n))
     enddo
     do n=1,nc2d
        write(lu,'(a,1x,2(i4,1x),a)') trim(cvars2d(n)),   1,0,trim(cvars2d(n))
     enddo
     do n=1,mvars
        write(lu,'(a,1x,2(i4,1x),a)') trim(cvarsmd(n)),   1,0,trim(cvarsmd(n))
     enddo
     write(lu,'(a)') 'ENDVARS'
     close(lu)

  end if ! mype=0
   
  return
end subroutine write_bkgvars2_grid

subroutine load_grid2(grid_in,grid_out)
!$$$  subroutine documentation block
!
! subprogram:    load_grid2
!
!   prgrmmr:
!
! abstract: 
!
! program history log:
!   2008-03-27  safford -- add subprogram doc block, rm unused vars
!
!   input argument list:
!     grid_in  - input grid 
!
!   output argument list:
!     grid_out - output grid
!
! attributes:
!   language:  f90
!   machine:
!
!$$$
  use kinds, only: i_kind,r_kind
  use gridmod, only:  nlat,nlon
  implicit none

  real(r_kind),dimension(nlat,nlon)  ,intent(in   ) :: grid_in        ! input grid
  real(r_kind),dimension(nlon,nlat-2),intent(  out) :: grid_out    ! output grid

  integer(i_kind) i,j,nlatm1,jj,j2

! Transfer contents of local array to output array.
  nlatm1=nlat-1
  do j=2,nlatm1
     jj=j-1
     j2=nlat-j+1
     do i=1,nlon
        grid_out(i,jj)=grid_in(j2,i)
     end do
  end do

  return
end subroutine load_grid2

subroutine fill_ns2(grid_in,grid_out)
!$$$  subroutine documentation block
!
! subprogram:    fill_ns2
!
!   prgrmmr:
!
! abstract: 
!
! program history log:
!   2008-03-27  safford -- add subprogram doc block, rm unused vars
!
!   input argument list:
!     grid_in  - input grid 
!
!   output argument list:
!     grid_out - output grid
!
! attributes:
!   language:  f90
!   machine:
!
!$$$
  use kinds, only: i_kind,r_kind
  use constants, only: zero,one
  use gridmod, only: nlat,nlon
  implicit none

  real(r_kind),dimension(nlon,nlat-2),intent(in   ) :: grid_in  ! input grid
  real(r_kind),dimension(nlat,nlon)  ,intent(  out) :: grid_out  ! output grid
!  Declare local variables
  integer(i_kind) i,j,jj,nlatm2
  real(r_kind) rnlon,sumn,sums

!  Transfer contents of input grid to local work array
!  Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
     jj=nlat-j
     do i=1,nlon
        grid_out(j,i)=grid_in(i,jj)
     end do
  end do

!  Compute mean along southern and northern latitudes
  sumn=zero
  sums=zero
  nlatm2=nlat-2
  do i=1,nlon
     sumn=sumn+grid_in(i,1)
     sums=sums+grid_in(i,nlatm2)
  end do
  rnlon=one/float(nlon)
  sumn=sumn*rnlon
  sums=sums*rnlon

!  Load means into local work array
  do i=1,nlon
     grid_out(1,i)   =sums
     grid_out(nlat,i)=sumn
  end do

  return
end subroutine fill_ns2

