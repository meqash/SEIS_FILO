!=======================================================================
!   SEIS_FILO: 
!   SEISmological tools for Flat Isotropic Layered structure in the Ocean
!   Copyright (C) 2019 Takeshi Akuhara
!
!   This program is free software: you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation, either version 3 of the License, or
!   (at your option) any later version.
!
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with this program.  If not, see <https://www.gnu.org/licenses/>.
!
!
!   Contact information
!
!   Email  : akuhara @ eri. u-tokyo. ac. jp 
!   Address: Earthquake Research Institute, The Univesity of Tokyo
!           1-1-1, Yayoi, Bunkyo-ku, Tokyo 113-0032, Japan
!
!=======================================================================
module mod_interpreter
  use mod_trans_d_model
  use mod_vmodel
  use mod_sort
  use mod_const
  implicit none 
  
  type interpreter
     private
     integer :: nlay_max

     logical :: ocean_flag = .false.
     double precision :: ocean_thick = 0.d0
     double precision :: ocean_vp    = 1.5d0
     double precision :: ocean_rho   = 1.d0

     integer :: nbin_z
     integer :: nbin_vs
     integer :: nbin_vp

     integer, allocatable :: n_vsz(:, :)
     integer, allocatable :: n_vpz(:, :)
     integer, allocatable :: n_layers(:)

     double precision, allocatable :: vsz_mean(:)
     double precision, allocatable :: vpz_mean(:)
     
     double precision :: z_min
     double precision :: z_max
     double precision :: dz
     double precision :: vs_min
     double precision :: vs_max
     double precision :: dvs
     double precision :: vp_min
     double precision :: vp_max
     double precision :: dvp

     
     logical :: solve_vp = .true.

     double precision, allocatable :: wrk_vp(:), wrk_vs(:), wrk_z(:) 
     
   contains
     procedure :: get_vmodel => interpreter_get_vmodel
     procedure :: save_model => interpreter_save_model
     procedure :: get_nbin_z => interpreter_get_nbin_z
     procedure :: get_nbin_vs => interpreter_get_nbin_vs
     procedure :: get_nbin_vp => interpreter_get_nbin_vp
     procedure :: get_n_vpz => interpreter_get_n_vpz
     procedure :: get_n_vsz => interpreter_get_n_vsz
     procedure :: get_vpz_mean => interpreter_get_vpz_mean
     procedure :: get_vsz_mean => interpreter_get_vsz_mean
     procedure :: get_n_layers => interpreter_get_n_layers
     procedure :: get_dvs => interpreter_get_dvs
     procedure :: get_dvp => interpreter_get_dvp
     procedure :: get_dz => interpreter_get_dz
  end type interpreter
  
  interface interpreter
     module procedure init_interpreter
  end interface interpreter
  
contains

  !---------------------------------------------------------------------
  type(interpreter) function init_interpreter(nlay_max, z_min, z_max, &
       & nbin_z, vs_min, vs_max, nbin_vs, vp_min, vp_max, nbin_vp, &
       & ocean_flag, ocean_thick, ocean_vp, ocean_rho, solve_vp) &
       & result(self)
    integer, intent(in) :: nlay_max
    integer, intent(in) :: nbin_z, nbin_vs
    integer, intent(in), optional :: nbin_vp
    double precision, intent(in) :: z_min, z_max, vs_min, vs_max
    double precision, intent(in), optional :: vp_min, vp_max
    logical, intent(in), optional :: ocean_flag
    double precision, intent(in), optional :: ocean_thick, &
         ocean_vp, ocean_rho
    logical, intent(in), optional :: solve_vp

    self%nlay_max = nlay_max
    allocate(self%wrk_vp(nlay_max + 1))
    allocate(self%wrk_vs(nlay_max + 1))
    allocate(self%wrk_z(nlay_max + 1))

    
    self%z_min   = z_min
    self%z_max   = z_max
    self%nbin_z  = nbin_z
    self%vs_min  = vs_min
    self%vs_max  = vs_max
    self%nbin_vs = nbin_vs
    
    self%dz  = (z_max - z_min) / dble(nbin_z)
    self%dvs = (vs_max - vs_min) / dble(nbin_vs)
    
    allocate(self%n_vsz(nbin_vs, nbin_z))
    self%n_vsz = 0
    allocate(self%n_layers(self%nlay_max))
    self%n_layers = 0
    allocate(self%vsz_mean(nbin_z))
    self%vsz_mean = 0.d0

    if (present(ocean_flag)) then
       self%ocean_flag = ocean_flag
    end if

    if (present(ocean_thick)) then
       self%ocean_thick = ocean_thick
    end if

    if (present(ocean_vp)) then
       self%ocean_vp = ocean_vp
    end if
    
    if (present(ocean_rho)) then
       self%ocean_rho = ocean_rho
    end if

    if (present(solve_vp)) then
       if (.not. present(vp_min)) then
          write(0,*)"ERROR: vp_min is not given"
          stop
       end if
       if (.not. present(vp_max)) then
          write(0,*)"ERROR: vp_max is not given"
          stop
       end if
       if (.not. present(nbin_vp)) then
          write(0,*)"ERROR: nbin_vp is not given"
          stop
       end if
       self%solve_vp = solve_vp
       if (self%solve_vp) then
          self%vp_min = vp_min
          self%vp_max = vp_max
          self%nbin_vp = nbin_vp
          self%dvp = (vp_max - vp_min) / dble(nbin_vp)
          allocate(self%n_vpz(nbin_vp, nbin_z))
          self%n_vpz = 0
          allocate(self%vpz_mean(nbin_z))
          self%vpz_mean = 0.d0
       end if
    end if

    return 
  end function init_interpreter

  !---------------------------------------------------------------------
  
  type(vmodel) function interpreter_get_vmodel(self, tm) result(vm)
    class(interpreter), intent(inout) :: self
    type(trans_d_model), intent(in) :: tm
    integer :: i, i1, k

    
    k = tm%get_k()
    vm = init_vmodel()

    ! Set ocean layer
    if (self%ocean_flag) then
       call vm%set_nlay(k + 2) ! k middle layers + 1 ocean layer + 
                               ! 1 half space
       call vm%set_vp(1, self%ocean_vp)
       call vm%set_vs(1, -999.d0)
       call vm%set_rho(1, self%ocean_rho)
       call vm%set_h(1, self%ocean_thick)
       i1 = 1
    else
       call vm%set_nlay(k + 1)
       i1 = 0
    end if
    
    ! Translate trand_d_model to vmodel
    self%wrk_z(:) = tm%get_rx(id_z)
    self%wrk_vs(:) = tm%get_rx(id_vs)
    if (self%solve_vp) then
       self%wrk_vp(:) = tm%get_rx(id_vp)
    end if
    call quick_sort(self%wrk_z, 1, k, self%wrk_vs, self%wrk_vp)
    ! Middle layers
    do i = 1, k
       ! Vs
       call vm%set_vs(i+i1, self%wrk_vs(i))
       ! Vp
       if (self%solve_vp) then
          call vm%set_vp(i+i1, self%wrk_vp(i))
       else
          call vm%vs2vp_brocher(i+i1)
       end if
       ! Thickness
       if (i == 1) then
          call vm%set_h(i+i1, self%wrk_z(i))
       else if (i == k) then
          call vm%set_h(i+i1, self%z_max - self%wrk_z(i-1))
       else 
          call vm%set_h(i+i1, self%wrk_z(i) - self%wrk_z(i-1))
       end if
       ! Density
       call vm%vp2rho_brocher(i+i1)
    end do
    ! Bottom layer
    ! Vs
    call vm%set_vs(k+1+i1, 4.6d0) ! <- Fixed
    ! Vp
    call vm%vs2vp_brocher(k+1+i1)
    ! Thickness
    call vm%set_h(k+1+i1,  -99.d0) ! <- half space
    ! Density
    call vm%vp2rho_brocher(k+1+i1)
    
    return 
  end function interpreter_get_vmodel

  !---------------------------------------------------------------------

  function interpreter_get_n_vsz(self) result(n_vsz)
    class(interpreter), intent(in) :: self
    integer :: n_vsz(self%nbin_vs, self%nbin_z)

    n_vsz = self%n_vsz

    return 
  end function interpreter_get_n_vsz
  
  !---------------------------------------------------------------------

  function interpreter_get_n_vpz(self) result(n_vpz)
    class(interpreter), intent(in) :: self
    integer :: n_vpz(self%nbin_vp, self%nbin_z)

    n_vpz = self%n_vpz

    return 
  end function interpreter_get_n_vpz
  
  !---------------------------------------------------------------------

  function interpreter_get_vsz_mean(self) result(vsz_mean)
    class(interpreter), intent(in) :: self
    double precision :: vsz_mean(self%nbin_z)

    vsz_mean = self%vsz_mean

    return 
  end function interpreter_get_vsz_mean

  !---------------------------------------------------------------------

  function interpreter_get_vpz_mean(self) result(vpz_mean)
    class(interpreter), intent(in) :: self
    double precision :: vpz_mean(self%nbin_z)

    vpz_mean = self%vpz_mean

    return 
  end function interpreter_get_vpz_mean

  !---------------------------------------------------------------------

  function interpreter_get_n_layers(self) result(n_layers)
    class(interpreter), intent(in) :: self
    integer :: n_layers(self%nlay_max)
    
    n_layers = self%n_layers

    return 
  end function interpreter_get_n_layers
  
  !---------------------------------------------------------------------

  subroutine interpreter_save_model(self, tm, io)
    class(interpreter), intent(inout) :: self
    type(trans_d_model), intent(in) :: tm
    integer, intent(in) :: io
    type(vmodel) :: vm
    integer :: nlay
    integer :: ilay, iz, iz1, iz2, iv
    double precision :: tmpz, z, vp, vs
    
    vm = self%get_vmodel(tm)
    nlay = vm%get_nlay()
    
    self%n_layers(tm%get_k()) = self%n_layers(tm%get_k()) + 1
    tmpz = 0.d0
    do ilay = 1, nlay
       iz1 = int(tmpz / self%dz) + 1
       if (ilay < nlay) then
          iz2 = int((tmpz + vm%get_h(ilay)) / self%dz) + 1
       else
          iz2 = self%nbin_z + 1
       end if
       do iz = iz1, iz2 - 1
          z = (iz - 1) * self%dz
          vp = vm%get_vp(ilay)
          vs = vm%get_vs(ilay)
          
          write(io,*)vp, vs, z
          
          iv = int((vs - self%vs_min) / self%dvs) + 1
          self%n_vsz(iv, iz) = self%n_vsz(iv, iz) + 1
          self%vsz_mean(iz) = self%vsz_mean(iz) + vs
          if (self%solve_vp) then
             iv = int((vp - self%vp_min) / self%dvp) + 1
             self%n_vpz(iv, iz) = self%n_vpz(iv, iz) + 1
             self%vpz_mean(iz) = self%vpz_mean(iz) + vp
          end if
          
       end do
       tmpz = tmpz + vm%get_h(ilay) 
    end do
    
  end subroutine interpreter_save_model

  !---------------------------------------------------------------------

  integer function interpreter_get_nbin_z(self) result(nbin_z)
    class(interpreter), intent(in) ::self

    nbin_z = self%nbin_z
    
    return 
  end function interpreter_get_nbin_z
  
  !---------------------------------------------------------------------

  integer function interpreter_get_nbin_vs(self) result(nbin_vs)
    class(interpreter), intent(in) ::self

    nbin_vs = self%nbin_vs
    
    return 
  end function interpreter_get_nbin_vs
  
  !---------------------------------------------------------------------

  integer function interpreter_get_nbin_vp(self) result(nbin_vp)
    class(interpreter), intent(in) ::self

    nbin_vp = self%nbin_vp
    
    return 
  end function interpreter_get_nbin_vp
  
  !---------------------------------------------------------------------  

  double precision function interpreter_get_dvs(self) result(dvs)
    class(interpreter), intent(in) ::self

    dvs = self%dvs
    
    return 
  end function interpreter_get_dvs
  
  !---------------------------------------------------------------------  
  
  double precision function interpreter_get_dvp(self) result(dvp)
    class(interpreter), intent(in) ::self

    dvp = self%dvp
    
    return 
  end function interpreter_get_dvp
  
  !---------------------------------------------------------------------  

  double precision function interpreter_get_dz(self) result(dz)
    class(interpreter), intent(in) ::self
    
    dz = self%dz
    
    return 
  end function interpreter_get_dz
  
  !---------------------------------------------------------------------  
  
end module mod_interpreter

