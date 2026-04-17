import sys

mainModule = sys.modules.get("__main__")
mainFile = getattr(mainModule, "__file__", "") or ""
if "mutmut" in mainFile and "mutmut.__main__" not in sys.modules:
    sys.modules["mutmut.__main__"] = mainModule
