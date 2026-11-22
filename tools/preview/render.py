"""Render a dumped Roblox part list (from robloxmock) to a PNG with simple ray casting."""
import sys, numpy as np
from PIL import Image

def load(path):
    parts=[]
    for line in open(path):
        f=line.split()
        if len(f)<20: continue
        shape=f[0]; v=list(map(float,f[1:19]))
        size=np.array(v[0:3]); pos=np.array(v[3:6])
        R=np.array([v[6:9],v[9:12],v[12:15]]).T  # columns: right, up, back
        col=np.array(v[15:18]); mat=f[19]
        parts.append((shape,size,pos,R,col,mat))
    return parts

def intersect(shape,size,pos,R,o,d):
    # transform rays into local space
    lo=(o-pos)@R; ld=d@R
    h=size/2
    n=len(d); t=np.full(n,np.inf); nrm=np.zeros((n,3))
    if shape in("Ball","Ellipsoid"):
        if shape=="Ball": r=np.full(3,size.min()/2)
        else: r=h
        so=lo/r; sd=ld/r
        a=(sd*sd).sum(1); b=2*(so*sd).sum(1); c=(so*so).sum(1)-1
        disc=b*b-4*a*c; ok=disc>0
        tt=np.where(ok,(-b-np.sqrt(np.maximum(disc,0)))/(2*a),np.inf)
        tt=np.where(tt>1e-4,tt,np.inf); t=tt
        p=lo+ld*t[:,None]; nl=p/(r*r)
    elif shape=="Cylinder":
        rr=min(size[1],size[2])/2
        a=ld[:,1]**2+ld[:,2]**2; b=2*(lo[:,1]*ld[:,1]+lo[:,2]*ld[:,2]); c=lo[:,1]**2+lo[:,2]**2-rr*rr
        disc=b*b-4*a*c; ok=(disc>0)&(a>1e-9)
        t1=np.where(ok,(-b-np.sqrt(np.maximum(disc,0)))/(2*np.maximum(a,1e-9)),np.inf)
        x1=lo[:,0]+ld[:,0]*t1; ok1=(np.abs(x1)<=h[0])&(t1>1e-4)
        tcyl=np.where(ok1,t1,np.inf)
        # caps
        with np.errstate(divide='ignore',invalid='ignore'):
            tc=np.minimum(np.where(ld[:,0]!=0,(h[0]-lo[:,0])/ld[:,0],np.inf),np.where(ld[:,0]!=0,(-h[0]-lo[:,0])/ld[:,0],np.inf))
            tc2=np.maximum(np.where(ld[:,0]!=0,(h[0]-lo[:,0])/ld[:,0],np.inf),np.where(ld[:,0]!=0,(-h[0]-lo[:,0])/ld[:,0],np.inf))
        tcap=np.where(tc>1e-4,tc,tc2)
        pc=lo+ld*tcap[:,None]; okc=(pc[:,1]**2+pc[:,2]**2<=rr*rr)&(tcap>1e-4)
        tcap=np.where(okc,tcap,np.inf)
        t=np.minimum(tcyl,tcap)
        p=lo+ld*t[:,None]
        nl=np.where((tcap<tcyl)[:,None],np.stack([np.sign(p[:,0]),np.zeros(n),np.zeros(n)],1),np.stack([np.zeros(n),p[:,1],p[:,2]],1))
    else: # Block / Wedge (wedge: keep where y <= slope)
        with np.errstate(divide='ignore',invalid='ignore'):
            t1=(-h-lo)/ld; t2=(h-lo)/ld
        tmin=np.nanmax(np.minimum(t1,t2),1); tmax=np.nanmin(np.maximum(t1,t2),1)
        ok=(tmax>=tmin)&(tmax>1e-4)
        t=np.where(ok,np.where(tmin>1e-4,tmin,np.inf),np.inf)
        p=lo+ld*t[:,None]
        nl=np.zeros((n,3)); ax=np.argmax(np.abs(p/h),1); nl[np.arange(n),ax]=np.sign(p[np.arange(n),ax])
        if shape=="Wedge":
            # Roblox wedge: low at the front (-Z), high at the back (+Z): solid where y/hy <= z/hz.
            inside=(p[:,1]/h[1]-p[:,2]/h[2])<=1e-6
            tbox=np.where(inside,t,np.inf)
            pn=np.array([0,1/h[1],-1/h[2]])
            denom=ld@pn
            with np.errstate(divide='ignore',invalid='ignore'):
                tp=-(lo@pn)/denom
            pp=lo+ld*tp[:,None]
            okp=(denom<0)&(tp>1e-4)&(np.abs(pp)<=h*1.0001).all(1)
            tp=np.where(okp,tp,np.inf)
            usep=tp<tbox
            t=np.minimum(tbox,tp)
            nl=np.where(usep[:,None],np.tile(pn,(n,1)),nl)
    nw=np.nan_to_num(nl)@R.T
    nw=nw/np.maximum(np.linalg.norm(nw,axis=1,keepdims=True),1e-9)
    return t,nw

def render(parts,out,views,W=360,title=""):
    imgs=[]
    for yaw,pitch in views:
        cy,sy,cp,sp=np.cos(yaw),np.sin(yaw),np.cos(pitch),np.sin(pitch)
        allp=np.array([p[2] for p in parts]); center=allp.mean(0); ext=np.ptp(allp,0).max()+2
        dist=ext*1.25
        fwd=np.array([-sy*cp, -sp, -cy*cp]); campos=center-fwd*dist
        right=np.cross(fwd,[0,1,0]); right/=np.linalg.norm(right); up=np.cross(right,fwd)
        xs=np.linspace(-1,1,W); X,Y=np.meshgrid(xs,-xs)
        fov=0.42
        d=fwd[None,:]+X.reshape(-1,1)*right*fov+Y.reshape(-1,1)*up*fov
        d/=np.linalg.norm(d,axis=1,keepdims=True)
        o=np.repeat(campos[None,:],len(d),0)
        best=np.full(len(d),np.inf); col=np.ones((len(d),3))*np.array([0.93,0.94,0.97])
        light=-fwd*0.7+up*0.6-right*0.35; light/=np.linalg.norm(light)
        for shape,size,pos,R,c,mat in parts:
            t,n=intersect(shape,size,pos,R,o,d)
            m=t<best
            if not m.any(): continue
            best[m]=t[m]
            nn=n[m]; nn=np.where(((nn*d[m]).sum(1)>0)[:,None],-nn,nn)
            diff=np.clip(nn@light,0,1)
            hv=light-d[m]; hv/=np.linalg.norm(hv,axis=1,keepdims=True)
            spec=np.clip((nn*hv).sum(1),0,1)**30*(0.6 if mat in("Metal","Neon") else 0.25)
            amb=0.35 if mat!="Neon" else 0.9
            col[m]=np.clip(c[None,:]*(amb+0.7*diff[:,None])+spec[:,None],0,1)
        imgs.append((col.reshape(W,W,3)*255).astype(np.uint8))
    Image.fromarray(np.concatenate(imgs,1)).save(out)

if __name__=="__main__":
    parts=load(sys.argv[1])
    views=[(np.pi,0.08),(np.pi-0.75,0.15),(np.pi/2,0.05)]   # front, three-quarter, side
    render(parts,sys.argv[2],views,W=420)
    print(len(parts),"parts rendered")
