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
program main
  use mod_param
  use mod_vmodel
  use mod_rayleigh
  implicit none 
  integer :: n_arg
  character(len=200) :: param_file
  type(param) :: para
  type(vmodel) :: vm
  type(rayleigh) :: ray
  
  ! Get parameter file name from command line argument
  n_arg = command_argument_count()
  if (n_arg /= 1) then
     write(0, *)"USAGE: rayleigh_fwd [parameter file]"
     stop
  end if
  call get_command_argument(1, param_file)

  ! Read parameter file
  para = init_param(param_file)
  
  ! Set velocity model
  vm = init_vmodel()
  call vm%read_file(para%get_vmod_in())
  
  ! Calculate dispersion curve
  ray = init_rayleigh(&
       & vm   = vm, &
       & fmin = para%get_fmin(), &
       & fmax = para%get_fmax(), &
       & df   = para%get_df(), &
       & cmin = para%get_cmin(), &
       & cmax = para%get_cmax(), &
       & dc   = para%get_dc(), &
       & ray_out = para%get_ray_out() &
       & )
  
  call ray%dispersion()
 
  
  
  

  stop
end program main
