module mod_parallel
  use mod_trans_d_model
  use mod_mcmc
  implicit none 

  type parallel
     private
     integer :: n_proc
     integer :: rank
     integer :: n_chain
     type(trans_d_model), allocatable :: tm(:)
     type(mcmc), allocatable :: mc(:)
   contains
     procedure :: set_tm => parallel_set_tm
     procedure :: get_tm => parallel_get_tm
     procedure :: set_mc => parallel_set_mc
     procedure :: get_mc => parallel_get_mc
  end type parallel

  interface parallel
     module procedure init_parallel
  end interface parallel

contains
  
  !---------------------------------------------------------------------
  
  type(parallel) function init_parallel(n_proc, rank, n_chain) &
       & result(self)
    integer, intent(in) :: n_proc, rank, n_chain
    
    self%n_proc = n_proc
    self%rank = rank
    self%n_chain = n_chain
    
    allocate(self%tm(n_chain))
    allocate(self%mc(n_chain))
    
    return 
  end function init_parallel

  !---------------------------------------------------------------------

  subroutine parallel_set_tm(self, i, tm)
    class(parallel), intent(inout) :: self
    integer, intent(in) :: i
    type(trans_d_model), intent(in) :: tm
    
    if (i < 0 .or. i > self%n_chain) then
       write(0, *)"ERROR: in valid i (parallel_set_tm)"
       stop
    end if
    self%tm(i) = tm
    
    return 
  end subroutine parallel_set_tm

  !---------------------------------------------------------------------

  type(trans_d_model) function parallel_get_tm(self, i) result(tm)
    class(parallel), intent(inout) :: self
    integer, intent(in) :: i
    if (i < 0 .or. i > self%n_chain) then
       write(0, *)"ERROR: in valid i (parallel_get_tm)"
       stop
    end if

    tm = self%tm(i)

    return 
  end function parallel_get_tm

  !---------------------------------------------------------------------

  subroutine parallel_set_mc(self, i, mc)
    class(parallel), intent(inout) :: self
    integer, intent(in) :: i
    type(mcmc), intent(in) :: mc
    
    if (i < 0 .or. i > self%n_chain) then
       write(0, *)"ERROR: in valid i (parallel_set_mc)"
       stop
    end if
    self%mc(i) = mc
    
    return 
  end subroutine parallel_set_mc

  !---------------------------------------------------------------------

  type(mcmc) function parallel_get_mc(self, i) result(mc)
    class(parallel), intent(inout) :: self
    integer, intent(in) :: i
    if (i < 0 .or. i > self%n_chain) then
       write(0, *)"ERROR: in valid i (parallel_get_mc)"
       stop
    end if

    mc = self%mc(i)

    return 
  end function parallel_get_mc
    
  !---------------------------------------------------------------------
  
end module mod_parallel
