"""Evita que CTkCheckBox se redibuje cuando la variable se reescribe con el mismo valor."""
from customtkinter import CTkCheckBox


def _apply():
    if getattr(CTkCheckBox, "_xp_patched", False):
        return
    orig = CTkCheckBox._variable_callback

    def _cb(self, *a):
        try:
            v = self._variable.get()
            if v == self._onvalue and self._check_state is True:
                return
            if v == self._offvalue and self._check_state is False:
                return
        except Exception:
            pass
        return orig(self, *a)

    CTkCheckBox._variable_callback = _cb
    CTkCheckBox._xp_patched = True


_apply()
