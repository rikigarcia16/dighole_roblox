import ctypes, ctypes.wintypes as wt, time
from PIL import Image
u=ctypes.windll.user32; g=ctypes.windll.gdi32
u.SetProcessDPIAware()
def find(title_part):
    res=[]
    @ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
    def cb(h,l):
        n=u.GetWindowTextLengthW(h)
        if n:
            b=ctypes.create_unicode_buffer(n+1); u.GetWindowTextW(h,b,n+1)
            if title_part in b.value and u.IsWindowVisible(h): res.append(h)
        return True
    u.EnumWindows(cb,0); return res[0] if res else None
class BMI(ctypes.Structure):
    _fields_=[("biSize",wt.DWORD),("biWidth",wt.LONG),("biHeight",wt.LONG),("biPlanes",wt.WORD),("biBitCount",wt.WORD),("biCompression",wt.DWORD),("biSizeImage",wt.DWORD),("biXPelsPerMeter",wt.LONG),("biYPelsPerMeter",wt.LONG),("biClrUsed",wt.DWORD),("biClrImportant",wt.DWORD)]
class Grabber:
    def __init__(self,h):
        self.h=h; r=wt.RECT(); u.GetWindowRect(h,ctypes.byref(r)); self.w=r.right-r.left; self.ht=r.bottom-r.top
        self.wdc=u.GetWindowDC(h); self.mdc=g.CreateCompatibleDC(self.wdc); self.bmp=g.CreateCompatibleBitmap(self.wdc,self.w,self.ht); g.SelectObject(self.mdc,self.bmp)
        self.bmi=BMI(); self.bmi.biSize=ctypes.sizeof(BMI); self.bmi.biWidth=self.w; self.bmi.biHeight=-self.ht; self.bmi.biPlanes=1; self.bmi.biBitCount=32
        self.buf=ctypes.create_string_buffer(self.w*self.ht*4)
    def grab(self):
        u.PrintWindow(self.h,self.mdc,2)
        g.GetDIBits(self.mdc,self.bmp,0,self.ht,self.buf,ctypes.byref(self.bmi),0)
        return Image.frombuffer("RGB",(self.w,self.ht),self.buf,"raw","BGRX",0,1)
if __name__=="__main__":
    h=find("Roblox Studio"); print("hwnd",h)
    G=Grabber(h); print(G.w,G.ht)
    t=time.time(); n=10
    for i in range(n): im=G.grab()
    print("ms/frame",(time.time()-t)/n*1000)
    im.save("test_full.jpg",quality=85)
