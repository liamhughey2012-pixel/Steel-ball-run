import re, numpy as np, subprocess
src=open("/home/user/liamhughey2012-pixel/steel-ball-run/src/client/TuskAnimation.lua").read()
poses={}
for m in re.finditer(r'^\t(\w+) = \{(.*)\},?$',src,flags=re.M):
    name,body=m.group(1),m.group(2)
    joints=dict((j,[float(x) for x in v.split(',')]) for j,v in re.findall(r'(\w+) = \{ ([-\d., ]+) \}',body))
    if joints: poses[name]=joints
def T(x,y,z): M=np.eye(4); M[:3,3]=[x,y,z]; return M
def Rx(a): c,s=np.cos(a),np.sin(a); M=np.eye(4); M[1,1]=c;M[1,2]=-s;M[2,1]=s;M[2,2]=c; return M
def Ry(a): c,s=np.cos(a),np.sin(a); M=np.eye(4); M[0,0]=c;M[0,2]=s;M[2,0]=-s;M[2,2]=c; return M
def Rz(a): c,s=np.cos(a),np.sin(a); M=np.eye(4); M[0,0]=c;M[0,1]=-s;M[1,0]=s;M[1,1]=c; return M
def ang(x,y,z): return Rx(x)@Ry(y)@Rz(z)
inv=np.linalg.inv
# rest-pose parts: name -> (size, centre, colour)
skin=(0.92,0.75,0.6); purple=(0.4,0.25,0.59); pants=(0.27,0.18,0.43)
parts={"HumanoidRootPart":((2,2,1),(0,3,0),None),"LowerTorso":((2,0.4,1),(0,2.95,0),purple),"UpperTorso":((2,1.6,1),(0,3.95,0),purple),"Head":((1.2,1.2,1.2),(0,5.3,0),skin)}
for s,side in ((-1,"Left"),(1,"Right")):
    parts[side+"UpperArm"]=((1,1.2,1),(s*1.5,4.15,0),purple); parts[side+"LowerArm"]=((1,1.1,1),(s*1.5,3.0,0),purple); parts[side+"Hand"]=((1,0.3,1),(s*1.5,2.3,0),skin)
    parts[side+"UpperLeg"]=((1,1.2,1),(s*0.5,2.15,0),pants); parts[side+"LowerLeg"]=((1,1.15,1),(s*0.5,0.95,0),pants); parts[side+"Foot"]=((1,0.3,1),(s*0.5,0.2,0),(0.3,0.2,0.12))
# joints: name(in pose), part0, part1, pivot
J=[("Root","HumanoidRootPart","LowerTorso",(0,2.95,0)),("Waist","LowerTorso","UpperTorso",(0,3.15,0)),("Neck","UpperTorso","Head",(0,4.75,0))]
for s,side in ((-1,"Left"),(1,"Right")):
    J+=[(side+"Arm","UpperTorso",side+"UpperArm",(s*1.5,4.65,0)),(None,side+"UpperArm",side+"LowerArm",(s*1.5,3.55,0)),(None,side+"LowerArm",side+"Hand",(s*1.5,2.45,0)),
        (side+"Hip","LowerTorso",side+"UpperLeg",(s*0.5,2.75,0)),(side+"Knee",side+"UpperLeg",side+"LowerLeg",(s*0.5,1.55,0)),(None,side+"LowerLeg",side+"Foot",(s*0.5,0.35,0))]
rest={n:T(*p[1]) for n,p in parts.items()}
def posed(pose):
    world={"HumanoidRootPart":rest["HumanoidRootPart"]}
    for jn,p0,p1,piv in J:
        C0=inv(rest[p0])@T(*piv); C1=inv(rest[p1])@T(*piv)
        v=pose.get(jn) if jn else None
        if v:
            rot=ang(*np.radians(v[:3])); ty=v[3] if len(v)>3 else 0
            base_rot=C0.copy(); base_rot[:3,3]=0
            C0=T(*(C0[:3,3]+[0,ty,0]))@rot@base_rot
        world[p1]=world[p0]@C0@inv(C1)
    return world
def dump(world,path):
    with open(path,"w") as f:
        for n,(size,_,col) in parts.items():
            if col is None: continue
            M=world[n]; R=M[:3,:3]; p=M[:3,3]
            f.write("Block %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f SmoothPlastic\n"%(*size,*p,*R[:,0],*R[:,1],*R[:,2],*col))
import sys
names=sys.argv[1:]
for n in names:
    dump(posed(poses[n]),f"pose_{n}.txt")
print("ok", [n for n in names])
