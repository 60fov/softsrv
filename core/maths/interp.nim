template interp_mix*(a, b: proc(t: float): float, w, t: float): float =
  (1-w)*a(t) + w*b(t)

template interp_crossfade*(a, b: proc(t: float): float, t: float): float =
  interp_mix(a, b, t, t)

proc interp_sm_start2*(t: float): float = t * t
proc interp_sm_start3*(t: float): float = t * t * t
proc interp_sm_start4*(t: float): float = t * t * t * t
proc interp_sm_start5*(t: float): float = t * t * t * t * t

proc interp_sm_stop2*(t: float): float = 1 - interp_sm_start2(1-t)
proc interp_sm_stop3*(t: float): float = 1 - interp_sm_start3(1-t)
proc interp_sm_stop4*(t: float): float = 1 - interp_sm_start4(1-t)
proc interp_sm_stop5*(t: float): float = 1 - interp_sm_start5(1-t)

proc interp_sm_step2*(t: float): float = interp_crossfade(interp_sm_start2, interp_sm_stop2, t)
proc interp_sm_step3*(t: float): float = interp_crossfade(interp_sm_start3, interp_sm_stop3, t)
proc interp_sm_step4*(t: float): float = interp_crossfade(interp_sm_start4, interp_sm_stop4, t)
proc interp_sm_step5*(t: float): float = interp_crossfade(interp_sm_start5, interp_sm_stop5, t)

