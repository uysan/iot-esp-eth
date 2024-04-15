%
% IOT ESP Ethernet Board Antenna Simulation
%
% Based on the "inverted-f antenna (ifa) 2.4GHz" example located here:
% https://github.com/thliebig/openEMS/blob/master/matlab/examples/antennas/inverted_f.m
%
% Tested with
%  - Octave 5.2.0
%  - openEMS v0.0.35-108-gc651cce and v0.0.36-14-g6a13d81

close all; clear; clc ;
disp( [ "Started: "  datestr(clock()) ] ) ;
%init_ems % uncomment for v0.0.35, comment for v0.0.36
physical_constants ; % setup the simulation
unit = 1e-3; % all length in mm
area.width  = 60 ; % width of active area in mm
area.height = 100 ; % height of active area in mm

ant.w1 = 1.5 ; % width of the main stub from the tip
ant.w2 = 1 ; % width of the feeding point
ant.w3 = 3 ; % width of the shorting pin
ant.w4 = 3 ; % width of the main stub from shorting side
ant.l1 = 25.8 ; % length of the main stub
ant.s1 = 3.9 ; % space between feeding and shorting pins on top
ant.s2 = 3.9 ; % space between feeding and shorting pins on bottom
ant.h1 = 6 ; % height of the feeding line
ant.h2 = 0 ; % height of the feeding line at feeding point
ant.h3 = 0.5 ; % height of the shorting pin
ant.m1 = 0 ; % miter width for main stub
ant.m2 = 1 ; % miter width for shorting stub
ant.rp = [ 0 22.6 ] ; % antenna reference point with respect to board center
ant.fp = [ 2.8 ant.rp(2) ] ; % with respect to board center point
ant.exc_depth = 0.9 ;
ant.exc_width = ant.w2 ;
ant.g1 = 1 ; % ground overlap
ant.impedance = 50 ;
ant.th = 0 ; % metal thickness. i.e. 0 (1x time) or 0.035 (~10x time)
ant.thb = ant.th ; % tickness used for primitive boxes

% 4: show manual ant mesh, 3: show all manual meshes, 2: show smoothed mesh,
% 1: show all mesh, 0: show all mesh and run simulation
debug_ant_mesh = 0 ;

use_pec = 1 ; % 1: use PEC instead of lossy copper
use_tgnd = 2 ; % 1: use top gnd, 2: use smaller top gnd
use_bgnd = 2 ; % 1: use bottom gnd along with top gnd, 2: use smaller bot gnd
use_ignd = 1 ; % 1: use inner 1 & 2 gnd layers as large as the substrate
use_shield = 1 ; % 1: include shield around MCU into simulation
use_tr_line = 1 ; % 1: use transmission line
use_enclosure = 0 ; % 1: use plastic enclosure

%% setup FDTD parameter & excitation function
f0 = 2.44e9; % center frequency, 2.44e9
fc = 300e6; % 20 dB corner frequency, 300e6

% substrate setup
sub.thickness = 1.6 ; % thickness of substrate, 1.6mm pcb
sub.pp_er = 4.4 ; % preimpregnated layer's dielectric constant
sub.pp_tand = 0.018 ; % preimpregnated layer's loss tangent
sub.pp_kappa = sub.pp_tand*2*pi*f0*EPS0*sub.pp_er ; % electrical conductivity, S/m
sub.pp_thickness = 0.21 ; % for 7628 prepreg
sub.core_er = 4.6 ; % core dielectric constant
sub.core_tand = 0.018 ; % core loss tangent
sub.core_kappa = sub.core_tand*2*pi*f0*EPS0*sub.core_er ; % electrical conductivity, S/m
sub.core_thickness = sub.thickness - ( 2 * sub.pp_thickness ) ;
%sub.kappa = 1e-3 * 2*pi*f0 * EPS0*sub.epsR ; % electrical conductivity, S/m

% solder mask setup
mask.thickness = ant.th + 0.015 ; % thickness of solder mask
mask.er = 3.8 ; % solder mask's dielectric constant
mask.tand = 0.018 ; % loss tangent, 0.018
%mask.kappa  = 1e-3 * 2*pi*f0 * EPS0*mask.epsR ; % electrical conductivity, S/m
mask.kappa = mask.tand*2*pi*f0*EPS0*mask.er ; % electrical conductivity, S/m

% enclosure setup
enc.thickness = 2 ; % thickness of the plastic enclosure
enc.er = 3.3 ; % ABS dielectric constant
enc.tand = 0.02 ; % loss tangent
enc.kappa = enc.tand*2*pi*f0*EPS0*enc.er ; % electrical conductivity, S/m
enc.distance = 10 ; % distance from the PCB on all axes

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% size of the simulation box
SimBox = [ area.width*2 area.height*2 150 ] ;

if ( use_pec == 0 )
  ant.thb = 0 ;  % should be 0 since the sheet has a thickness
  if ( ant.th == 0 )
    disp( 'Error: Antenna thickness should be greater than 0 for a non-PEC design.' ) ;
    return ;
  endif
endif

FDTD = InitFDTD( 'NrTS', 1.2e6, 'EndCriteria', 1e-5 ) ; % ends below -50dB
FDTD = SetGaussExcite( FDTD, f0, fc ) ;
BC = { 'MUR' 'MUR' 'MUR' 'MUR' 'MUR' 'MUR' }; % boundary conditions
%BC = { 'PML_8' 'PML_8' 'PML_8' 'PML_8' 'PML_8' 'PML_8' }; % boundary conditions
%BC = { 'PEC' 'PEC' 'PEC' 'PEC' 'PEC' 'PEC' }; % boundary conditions
FDTD = SetBoundaryCond( FDTD, BC ) ;

%% setup CSXCAD geometry & mesh
CSX = InitCSX();

% calculate reference point (0,0,tickness), first point and antenna outer dimensions
bcp = [ 0 0 sub.thickness ] ;  % board center point on substrate top

% first point is on the lower left corner of the antenna feeding point
if ( ant.rp(1) == 0 ) % auto
  ant.rp(1) = ( ant.l1 / 2 ) - ( ant.w2 + ant.s1 + ant.w3 ) ; % align to center
endif
disp( [ "ant reference point (x,y): " num2str( ant.rp(1) ) ", " num2str( ant.rp(2) ) ] ) ;
arp = bcp + [ ant.rp(1) ant.rp(2) 0 ] ; % antenna reference point
afp = bcp + [ ant.fp(1) ant.fp(2) 0 ] ; % antenna feeding point

%initialize the mesh with the "air-box" dimensions
mesh.x = [-SimBox(1)/2 SimBox(1)/2] ;
mesh.y = [-SimBox(2)/2 SimBox(2)/2] ;
mesh.z = [-SimBox(3)/2 SimBox(3)/2] ;

max_mres = c0 / (f0+fc) / unit / 20 ; % 5.4707
mres = 0.15 ; % smaller than max metal mesh width
max_sbres = c0 / (f0+fc) / unit / 10 ; % 10.941
sbres = 4 ; % smaller than max substrate mesh width
max_shres = c0 / (f0+fc) / unit / 20 ; % 5.4707
shres = 0.3 ; % smaller than max metal mesh width
shres_z = 0.15 ; %
mres_z = 0.012 ; %
mres_1_3 = 1 * mres / 3 ;
mres_2_3 = 2 * mres / 3 ;
mres_z_1_3 = 1 * mres_z / 3 ;
mres_z_2_3 = 2 * mres_z / 3 ;
mres_margin = mres * 2 ; % 2.5
ant_mesh.x = [ ] ; % vertical lines for antenna, yz plane
ant_mesh.y = [ ] ; % horizontal lines for antenna, xz plane
ant_mesh.z = [ ] ; % orthogonal lines for antenna, xy plane
ant_mesh_t.z = [ ] ; % orthogonal lines for top copper, xy plane
ant_mesh_b.z = [ ] ; % orthogonal lines for bottom copper, xy plane
ant_mesh_i1.z = [ ] ; % orthogonal lines for inner1 copper, xy plane
ant_mesh_i2.z = [ ] ; % orthogonal lines for inner2 copper, xy plane
via_mesh_l.x = [ ] ; % vertical lines for vias to the left, yz plane
via_mesh_l.y = [ ] ; % horizontal lines for vias to the left, xz plane
via_mesh_r.x = [ ] ; % vertical lines for vias to the right, yz plane
via_mesh_r.y = [ ] ; % horizontal lines for vias to the right, xz plane
shield_mesh.x = [ ] ; % vertical lines for shield, yz plane
shield_mesh.y = [ ] ; % horizontal lines for shield, xz plane
shield_mesh.z = [ ] ; % orthogonal lines for shield, xy plane
enc_mesh.x = [ ] ; % vertical lines for enclosure, yz plane
enc_mesh.y = [ ] ; % horizontal lines for enclosure, xz plane
enc_mesh.z = [ ] ; % orthogonal lines for enclosure, xy plane
% need to have a mesh in z dimension for both ends of the substrate
if ( ant.th > 0 )
  start = arp ;
  stop = start + [ 0 0 ant.th ] ; % old: ant.th
  ant_mesh_t.z = [ ant_mesh_t.z start(3)-mres_z_2_3 start(3)+mres_z_1_3 stop(3)-mres_z_1_3 stop(3)+mres_z_2_3 ] ;
  start = arp - [ 0 0 sub.thickness+ant.th ] ;
  stop = start + [ 0 0 ant.th ] ; % old: ant.th
  ant_mesh_b.z = [ ant_mesh_b.z start(3)-mres_z_2_3 start(3)+mres_z_1_3 stop(3)-mres_z_1_3 stop(3)+mres_z_2_3 ] ;
  if ( use_ignd != 0 )
    start = arp - [ 0 0 sub.pp_thickness+ant.th ] ;
    stop = start + [ 0 0 ant.th ] ;
    ant_mesh_i1.z = [ ant_mesh_i1.z start(3)-mres_z_2_3 start(3)+mres_z_1_3 stop(3)-mres_z_1_3 stop(3)+mres_z_2_3 ] ;
    start = arp - [ 0 0 sub.thickness-sub.pp_thickness ] ;
    stop = start + [ 0 0 ant.th ] ;
    ant_mesh_i2.z = [ ant_mesh_i2.z start(3)-mres_z_2_3 start(3)+mres_z_1_3 stop(3)-mres_z_1_3 stop(3)+mres_z_2_3 ] ;
  endif
else % zero thickness metal
  ant_mesh.z = [ ant_mesh.z arp(3) arp(3)-sub.thickness ] ;
  if ( use_ignd != 0 )
    ant_mesh.z = [ ant_mesh.z arp(3)-sub.pp_thickness ] ;
    ant_mesh.z = [ ant_mesh.z arp(3)-sub.thickness+sub.pp_thickness ] ;
  endif
endif

% create antenna
if ( use_pec != 0 )
  CSX = AddMetal( CSX, 'ant' ); % create a perfect electric conductor (PEC)
else
  CSX = AddConductingSheet( CSX, 'ant', 59.6e6, ant.th ) ; % copper
endif
p =          [ afp(1) ; afp(2) ] ; % feeding point bottom left corner
p(:,end+1) = [ afp(1)+ant.w2 ; afp(2) ] ;
if( afp(1) != arp(1) )
  p(:,end+1) = [ afp(1)+ant.w2 ; afp(2)+ant.h2 ] ;
  tmpx = arp(1) - afp(1) ; % 45 degree track width
  tmpy = ant.w2 * tan( 2 * pi / 16 ) ;
  p(:,end+1) = [ afp(1)+ant.w2+tmpx ; afp(2)+ant.h2+tmpx ] ;
endif
p(:,end+1) = [ arp(1)+ant.w2 ; arp(2)+ant.h1 ] ;
p(:,end+1) = [ arp(1)+ant.w2+ant.s1 ; arp(2)+ant.h1 ] ;
if ( ant.s2 >= ant.s1 )  % ignore s2
  p(:,end+1) = [ arp(1)+ant.w2+ant.s1 ; arp(2)-ant.g1 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s1+ant.w3 ; arp(2)-ant.g1 ] ;
else
  p(:,end+1) = [ arp(1)+ant.w2+ant.s1 ; arp(2)+ant.h3+ant.w3 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s2+ant.m2 ; arp(2)+ant.h3+ant.w3 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s2 ; arp(2)+ant.h3+ant.w3-ant.m2 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s2 ; arp(2)-ant.g1 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s2+ant.w3 ; arp(2)-ant.g1 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s2+ant.w3 ; arp(2)+ant.h3 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s1+ant.w3-ant.m2 ; arp(2)+ant.h3 ] ;
  p(:,end+1) = [ arp(1)+ant.w2+ant.s1+ant.w3 ; arp(2)+ant.h3+ant.m2 ] ;
endif
p(:,end+1) = [ arp(1)+ant.w2+ant.s1+ant.w3 ; arp(2)+ant.h1+ant.w4-ant.m2 ] ;
p(:,end+1) = [ arp(1)+ant.w2+ant.s1+ant.w3-ant.m2 ; arp(2)+ant.h1+ant.w4 ] ;
if ( ant.m1 > 0 )
  p(:,end+1) = [ arp(1)-ant.l1+ant.w2+ant.s1+ant.w3+ant.m1 ; arp(2)+ant.h1+ant.w4 ] ;
  p(:,end+1) = [ arp(1)-ant.l1+ant.w2+ant.s1+ant.w3 ; arp(2)+ant.h1+ant.w4-ant.m1 ] ;
else
  p(:,end+1) = [ arp(1)-ant.l1+ant.w2+ant.s1+ant.w3 ; arp(2)+ant.h1+ant.w4 ] ;
endif
p(:,end+1) = [ arp(1)-ant.l1+ant.w2+ant.s1+ant.w3 ; arp(2)+ant.h1+ant.w4-ant.w1 ] ;
p(:,end+1) = [ arp(1) ; arp(2)+ant.h1+ant.w4-ant.w1 ] ; % inner corner
p(:,end+1) = [ arp(1) ; afp(2)+ant.h2+tmpx+tmpy ] ;
p(:,end+1) = [ arp(1)-tmpx ; afp(2)+ant.h2+tmpy ] ;
CSX = AddLinPoly( CSX, 'ant', 10, 'z', arp(3), p, ant.thb ) ; % antenna

% create antenna mesh
ant_mesh.x = [ ant_mesh.x arp(1)-mres_2_3 arp(1)+mres_1_3 ] ;
ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2-mres_1_3 arp(1)+ant.w2+mres_2_3 ] ;
ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2+ant.s1-mres_2_3 arp(1)+ant.w2+ant.s1+mres_1_3 ] ;
ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2+ant.s1+ant.w3-mres_1_3 arp(1)+ant.w2+ant.s1+ant.w3+mres_2_3 ] ;
ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2+ant.s1+ant.w3-ant.l1-mres_2_3 arp(1)+ant.w2+ant.s1+ant.w3-ant.l1+mres_1_3 ] ;
ant_mesh.x = [ ant_mesh.x afp(1)-mres_2_3 afp(1)+mres_1_3 ] ;
ant_mesh.x = [ ant_mesh.x afp(1)+ant.w2-mres_1_3 afp(1)+ant.w2+mres_2_3 ] ;
ant_mesh.y = [ ant_mesh.y arp(2)-mres_2_3 arp(2)+mres_1_3 ] ;
ant_mesh.y = [ ant_mesh.y arp(2)+ant.h1-mres_2_3 arp(2)+ant.h1+mres_1_3 ] ;
ant_mesh.y = [ ant_mesh.y arp(2)+ant.h1+ant.w4-mres_1_3 arp(2)+ant.h1+ant.w4+mres_2_3 ] ;
ant_mesh.y = [ ant_mesh.y arp(2)+ant.h1+ant.w4-ant.w1-mres_2_3 arp(2)+ant.h1+ant.w4-ant.w1+mres_1_3 ] ;
if ( ant.s2 < ant.s1 )
  ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2+ant.s2-mres_2_3 arp(1)+ant.w2+ant.s2+mres_1_3 ] ;
  ant_mesh.x = [ ant_mesh.x arp(1)+ant.w2+ant.s2+ant.w3-mres_1_3 arp(1)+ant.w2+ant.s2+ant.w3+mres_2_3 ] ;
  ant_mesh.y = [ ant_mesh.y arp(2)+ant.h3+ant.w3-mres_1_3 arp(2)+ant.h3+ant.w3+mres_2_3 ] ;
  ant_mesh.y = [ ant_mesh.y arp(2)+ant.h3-mres_2_3 arp(2)+ant.h3+mres_1_3 ] ;
endif
ant_mesh.y_max = max( ant_mesh.y ) ; % keep these for via mesh
ant_mesh.y_min = min( ant_mesh.y ) ;
ant_mesh.x_max = max( ant_mesh.x ) ;
ant_mesh.x_min = min( ant_mesh.x ) ;

% create transmission line
if ( use_tr_line != 0 )
  tfp = afp + [ 0.3 -2 0 ] ; % transmission line feeding point
  tl_width = 0.38 ; % 15mil
  tl_space = 0.25 ; % 10mil
  tl_taper = ( afp(2) - tfp(2) ) / 1 ;
  ant.exc_width = tl_width ;
  ant.exc_depth = tl_width ;
  p =          [ tfp(1) ; tfp(2) ] ;
  p(:,end+1) = [ tfp(1)+tl_width ; tfp(2) ] ;
  p(:,end+1) = [ tfp(1)+tl_width ; afp(2)-tl_taper ] ;
  p(:,end+1) = [ afp(1)+ant.w2 ; afp(2) ] ;
  p(:,end+1) = [ afp(1) ; afp(2) ] ;
  p(:,end+1) = [ tfp(1) ; afp(2)-tl_taper ] ;
  CSX = AddLinPoly( CSX, 'ant', 10, 'z', arp(3), p, ant.thb ) ; % transmission line
  %ant_mesh.x = [ ant_mesh.x tfp(1)-mres_2_3 tfp(1)+mres_1_3 ] ;
  %ant_mesh.x = [ ant_mesh.x tfp(1)+tl_width-mres_1_3 tfp(1)+tl_width+mres_2_3 ] ;
  ant_mesh.y = [ ant_mesh.y tfp(2)-mres_2_3 tfp(2)+mres_1_3 ] ;
else
  tfp = afp ; % transmission line feeding point is the same as antenna feeding point
  tl_space = ant.exc_width / 2 ;
endif

% plane points smaller than the substrate
ps =          [ bcp(1)+13.7 ; arp(2) ] ;
ps(:,end+1) = [ bcp(1)+14.2 ; arp(2)-0.5 ] ;
ps(:,end+1) = [ bcp(1)+14.2 ; bcp(2)+17.3 ] ;
ps(:,end+1) = [ bcp(1)+13.7 ; bcp(2)+16.8 ] ;
ps(:,end+1) = [ bcp(1)-13.7 ; bcp(2)+16.8 ] ;
ps(:,end+1) = [ bcp(1)-14.2 ; bcp(2)+17.3 ] ;
ps(:,end+1) = [ bcp(1)-14.2 ; arp(2)-0.5 ] ;
ps(:,end+1) = [ bcp(1)-13.7 ; arp(2) ] ;
% plane points as large as the substrate
pl =          [ bcp(1)+13.7 ; arp(2) ] ;
pl(:,end+1) = [ bcp(1)+14.2 ; arp(2)-0.5 ] ;
pl(:,end+1) = [ bcp(1)+14.2 ; bcp(2)-30.7 ] ;
pl(:,end+1) = [ bcp(1)+13.2 ; bcp(2)-31.7 ] ;
pl(:,end+1) = [ bcp(1)-13.2 ; bcp(2)-31.7 ] ;
pl(:,end+1) = [ bcp(1)-14.2 ; bcp(2)-30.7 ] ;
pl(:,end+1) = [ bcp(1)-14.2 ; arp(2)-0.5 ] ;
pl(:,end+1) = [ bcp(1)-13.7 ; arp(2) ] ;

%% create ground planes and vias
if ( use_pec != 0 )
  if ( use_bgnd != 0 )  % if bottom ground layer is enabled
    CSX = AddMetal( CSX, 'via' ) ; % a perfect electric conductor (PEC)
  endif
  CSX = AddMetal( CSX, 'tgndplane' ) ; % a perfect electric conductor (PEC)
  CSX = AddMetal( CSX, 'bgndplane' ) ; % a perfect electric conductor (PEC)
  if ( use_ignd != 0 )
    CSX = AddMetal( CSX, 'i1gndplane' ) ; % a perfect electric conductor (PEC)
    CSX = AddMetal( CSX, 'i2gndplane' ) ; % a perfect electric conductor (PEC)
  endif
else
  ant.thb = 0 ;  % should be 0 since the sheet has a thickness
  if ( use_bgnd != 0 )  % if bottom ground layer is enabled
    CSX = AddConductingSheet( CSX, 'via', 59.6e6, ant.th ) ; % copper
  endif
  CSX = AddConductingSheet( CSX, 'tgndplane', 59.6e6, ant.th ) ; % copper
  CSX = AddConductingSheet( CSX, 'bgndplane', 59.6e6, ant.th ) ; % copper
  CSX = AddConductingSheet( CSX, 'i1gndplane', 59.6e6, ant.th ) ; % copper
  CSX = AddConductingSheet( CSX, 'i2gndplane', 59.6e6, ant.th ) ; % copper
endif
% consistent with the substrate shape after this point
if ( use_tgnd > 1 ) % smaller layer
  p = ps ;
else % same as substrate
  p = pl ;
endif
% not consistent with the substrate shape after this point
if ( use_tr_line != 0 ) % transmission line
  p(:,end+1) = [ afp(1)-tl_space; afp(2) ] ;
  p(:,end+1) = [ tfp(1)-tl_space; afp(2)-tl_taper ] ;
  p(:,end+1) = [ tfp(1)-tl_space; tfp(2) ] ;
  p(:,end+1) = [ tfp(1)-tl_space; tfp(2)-ant.exc_depth ] ;
  p(:,end+1) = [ tfp(1)+tl_width+tl_space; tfp(2)-ant.exc_depth ] ;
  p(:,end+1) = [ tfp(1)+tl_width+tl_space; tfp(2) ] ;
  p(:,end+1) = [ tfp(1)+tl_width+tl_space; afp(2)-tl_taper ] ;
  p(:,end+1) = [ afp(1)+ant.w2+tl_space; afp(2) ] ;
else % direct feed to antenna
  p(:,end+1) = [ afp(1)-tl_space; afp(2) ] ;
  p(:,end+1) = [ afp(1)-tl_space ; afp(2)-ant.exc_depth ] ;
  p(:,end+1) = [ afp(1)+tl_space+ant.exc_width ; afp(2)-ant.exc_depth ] ;
  p(:,end+1) = [ afp(1)+tl_space+ant.exc_width ; afp(2) ] ;
endif
  CSX = AddLinPoly( CSX, 'tgndplane', 9, 'z', sub.thickness, p, ant.thb ) ; % top gnd
  tgnd.x_min = min( p(1,1:end) ) ;
  tgnd.x_max = max( p(1,1:end) ) ;
if ( use_bgnd != 0 )  % if bottom ground layer is enabled
  if ( use_bgnd > 1 ) % smaller
    p = ps ;
  else % same as substrate
    p = pl ;
  endif
  CSX = AddLinPoly( CSX, 'bgndplane', 9, 'z', -ant.thb, p, ant.thb ) ; % bottom gnd
  p = pl ;
  if ( use_ignd != 0 )  % if inner ground layers are enabled
    CSX = AddLinPoly( CSX, 'i1gndplane', 9, 'z', sub.thickness-sub.pp_thickness-ant.thb, p, ant.thb ) ; % inner1 gnd
    CSX = AddLinPoly( CSX, 'i2gndplane', 9, 'z', sub.pp_thickness, p, ant.thb ) ; % inner2 gnd
  endif
  % add required vias as cylinders
  rvia = 0.3 ; % via radius is 0.3mm, typical via hole diameter is 0.3mm
  pvia_x = 1 ; % 1mm pitch
  pvia_y = 1 ; % 1mm pitch
  start = afp + [ -(pvia_x/2+tl_space) -pvia_y/2  0 ] ; % top center
  stop = start + [ 0 0 -sub.thickness ] ; % bottom center
  tmpy = start(2) + rvia + mres_2_3 ;
  if( tmpy < (ant_mesh.y_min-mres_margin) )
    via_mesh_l.y(end+1) = tmpy ;
    via_mesh_r.y(end+1) = tmpy ;
  endif
  tmpy = start(2) + rvia - mres_1_3 ;
  if( tmpy < (ant_mesh.y_min-mres_margin) )
    via_mesh_l.y(end+1) = tmpy ;
    via_mesh_r.y(end+1) = tmpy ;
  endif
  tmpy = start(2) - rvia - mres_2_3 ;
  if( tmpy < (ant_mesh.y_min-mres_margin) )
    via_mesh_l.y(end+1) = tmpy ;
    via_mesh_r.y(end+1) = tmpy ;
  endif
  tmpy = start(2) - rvia + mres_1_3 ;
  if( tmpy < (ant_mesh.y_min-mres_margin) )
    via_mesh_l.y(end+1) = tmpy ;
    via_mesh_r.y(end+1) = tmpy ;
  endif
  %if ( start(2)+mres_margin+rvia < ant_mesh.y_min )
  %  via_mesh_l.y = [ via_mesh_l.y start(2)+rvia+mres_2_3 start(2)+rvia-mres_1_3 ] ;
  %  via_mesh_r.y = [ via_mesh_l.y start(2)+rvia+mres_2_3 start(2)+rvia-mres_1_3 ] ;
  %elseif ( start(2)+mres_margin < ant_mesh.y_min )
  %  via_mesh_l.y = [ via_mesh_l.y start(2)-rvia-mres_2_3 start(2)-rvia+mres_1_3 ] ;
  %  via_mesh_r.y = [ via_mesh_l.y start(2)-rvia-mres_2_3 start(2)-rvia+mres_1_3 ] ;
  %endif
  via_mesh_l.x = [ via_mesh_l.x ant_mesh.x_min ] ;
  via_mesh_r.x = [ via_mesh_r.x ant_mesh.x_max ] ;
  for cnta = 1:50 % left side of the antenna
    CSX = AddCylinder( CSX, 'via', 9,  start, stop, rvia ) ; % gnd short stub via
    tmpx = start(1) + rvia + mres_2_3 ;
    if( tmpx < (ant_mesh.x_min-mres_margin) )
      via_mesh_l.x(end+1) = tmpx ;
    endif
    tmpx = start(1) + rvia - mres_1_3 ;
    if( tmpx < (ant_mesh.x_min-mres_margin) )
      via_mesh_l.x(end+1) = tmpx ;
    endif
    tmpx = start(1) - rvia - mres_2_3 ;
    if( tmpx < (ant_mesh.x_min-mres_margin) )
      via_mesh_l.x(end+1) = tmpx ;
    endif
    tmpx = start(1) - rvia + mres_1_3 ;
    if( tmpx < (ant_mesh.x_min-mres_margin) )
      via_mesh_l.x(end+1) = tmpx ;
    endif
    start = start - [ pvia_x 0  0 ] ; % top center
    stop = start + [ 0 0 -sub.thickness ] ; % bottom center
    if ( start(1)-rvia < tgnd.x_min )
      break ;
    endif
  endfor
  %if ( use_tr_line != 0 )
    %start = afp + [ pvia_x/2+tl_space+tl_width+tl_taper_width*2 -pvia_y/2  0 ] ; % top center
  %else
    start = afp + [ pvia_x/2+tl_space+ant.w2 -pvia_y/2  0 ] ; % top center
  %endif
  stop = start + [ 0 0 -sub.thickness ] ; % bottom center
  for cnta = 1:50 % right side of the antenna
    CSX = AddCylinder( CSX, 'via', 9,  start, stop, rvia ) ; % gnd short stub via
    tmpx = start(1) + rvia + mres_2_3 ;
    if( tmpx > (ant_mesh.x_max+mres_margin) )
      via_mesh_r.x(end+1) = tmpx ;
    endif
    tmpx = start(1) + rvia - mres_1_3 ;
    if( tmpx > (ant_mesh.x_max+mres_margin) )
      via_mesh_r.x(end+1) = tmpx ;
    endif
    tmpx = start(1) - rvia - mres_2_3 ;
    if( tmpx > (ant_mesh.x_max+mres_margin) )
      via_mesh_r.x(end+1) = tmpx ;
    endif
    tmpx = start(1) - rvia + mres_1_3 ;
    if( tmpx > (ant_mesh.x_max+mres_margin) )
      via_mesh_r.x(end+1) = tmpx ;
    endif
    start = start + [  pvia_x 0  0 ] ; % top center
    stop = start +  [  0      0 -sub.thickness ] ; % bottom center
    if ( start(1)+rvia > tgnd.x_max )
      break ;
    endif
  endfor
endif

if ( use_shield != 0 )
  if ( use_pec != 0 )
    CSX = AddMetal( CSX, 'shield' ) ; % a perfect electric conductor (PEC)
  else
    CSX = AddConductingSheet( CSX, 'shield', 6.2e6, ant.th ) ; % steel
  endif
  % height 3.6mm, thickness 0.2mm, window height 0.8mm
  scp = bcp + [ 0 13.2 0 ] ; % shield center point
  % horizontal plate
  start = scp + [ -8.4 -8.4 3.4 ] ; % lower left
  stop = scp + [ 8.4 8.4 3.6 ] ; % upper right
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.z = [ shield_mesh.z (stop(3)-start(3))/2+start(3) ] ;
  % vertical plates x 4
  start = scp + [ -8.4 -8.4 0.8 ] ; % lower left, left
  stop = scp + [ -8.2 8.4 3.4 ] ; % upper right, left
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ 8.2 -8.4 0.8 ] ; % lower left, right
  stop = scp + [ 8.4 8.4 3.4 ] ; % upper right, right
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -8.4 8.2 0.8 ] ; % lower left, top
  stop = scp + [ 8.4 8.4 3.4 ] ; % upper right, top
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -8.4 -8.4 0.8 ] ; % lower left, bottom
  stop = scp + [ 8.4 -8.2 3.4 ] ; % upper right, bottom
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.z = [ shield_mesh.z (stop(3)-start(3))/2+start(3) ] ;
  % vertical pad plates x 12
  start = scp + [ -8.4 -8.4 0 ] ; % lower left, left 1
  stop = scp + [ -8.2 -4.5 0.8 ] ; % upper right, left 1
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.y = [ shield_mesh.y (stop(2)-start(2))/2+start(2) ] ;
  start = scp + [ -8.4 -1.5 0 ] ; % lower left, left 2
  stop = scp + [ -8.2 1.5 0.8 ] ; % upper right, left 2
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.y = [ shield_mesh.y (stop(2)-start(2))/2+start(2) ] ;
  start = scp + [ -8.4 4.5 0 ] ; % lower left, left 3
  stop = scp + [ -8.2 8.4 0.8 ] ; % upper right, left 3
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.y = [ shield_mesh.y (stop(2)-start(2))/2+start(2) ] ;
  start = scp + [ 8.2 -8.4 0 ] ; % lower left, right 1
  stop = scp + [ 8.4 -4.5 0.8 ] ; % upper right, right 1
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ 8.2 -1.5 0 ] ; % lower left, right 2
  stop = scp + [ 8.4 1.5 0.8 ] ; % upper right, right 2
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ 8.2 4.5 0 ] ; % lower left, right 3
  stop = scp + [ 8.4 8.4 0.8 ] ; % upper right, right 3
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -8.4 8.2 0 ] ; % lower left, top 1
  stop = scp + [ -4.5 8.4 0.8 ] ; % upper right, top 1
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -1.5 8.2 0 ] ; % lower left, top 2
  stop = scp + [ 1.5 8.4 0.8 ] ; % upper right, top 2
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ 4.5 8.2 0 ] ; % lower left, top 3
  stop = scp + [ 8.4 8.4 0.8 ] ; % upper right, top 3
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -8.4 -8.2 0 ] ; % lower left, bottom 1
  stop = scp + [ -4.5 -8.4 0.8 ] ; % upper right, bottom 1
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ -1.5 -8.2 0 ] ; % lower left, bottom 2
  stop = scp + [ 1.5 -8.4 0.8 ] ; % upper right, bottom 2
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  start = scp + [ 4.5 -8.2 0 ] ; % lower left, bottom 3
  stop = scp + [ 8.4 -8.4 0.8 ] ; % upper right, bottom 3
  CSX = AddBox( CSX, 'shield', 9, start, stop ) ;
  shield_mesh.y = [ shield_mesh.y (stop(2)-start(2))/2+start(2) ] ;
  shield_mesh.z = [ shield_mesh.z (stop(3)-start(3))/2+start(3) ] ;
  % grounding tracks
  p =          [ scp(1)+1.3 ; scp(2)+8.4 ] ;
  p(:,end+1) = [ scp(1)-8.4 ; scp(2)+8.4 ] ;
  p(:,end+1) = [ scp(1)-8.4 ; scp(2)-8.4 ] ;
  p(:,end+1) = [ scp(1)+8.4 ; scp(2)-8.4 ] ;
  p(:,end+1) = [ scp(1)+8.4 ; scp(2)+8.4 ] ;
  p(:,end+1) = [ scp(1)+4.6 ; scp(2)+8.4 ] ;
  p(:,end+1) = [ scp(1)+4.6 ; scp(2)+7.9 ] ;
  p(:,end+1) = [ scp(1)+7.9 ; scp(2)+7.9 ] ;
  p(:,end+1) = [ scp(1)+7.9 ; scp(2)-7.9 ] ;
  p(:,end+1) = [ scp(1)-7.9 ; scp(2)-7.9 ] ;
  p(:,end+1) = [ scp(1)-7.9 ; scp(2)+7.9 ] ;
  p(:,end+1) = [ scp(1)+1.3 ; scp(2)+7.9 ] ;
  CSX = AddLinPoly( CSX, 'shield', 9, 'z', sub.thickness, p, ant.thb ) ; % shield grounding tracks
  shield_mesh.y = [ shield_mesh.y min( [ ant_mesh.y via_mesh_l.y via_mesh_r.y ] ) ] ;
  shield_mesh.z = [ shield_mesh.z max( ant_mesh.z ) ] ;
endif

% create substrate core and preimpregnated layers
p =          [ bcp(1)-13.72 ; bcp(2)-32.26 ] ;
p(:,end+1) = [ bcp(1)-14.73 ; bcp(2)-31.24 ] ;
p(:,end+1) = [ bcp(1)-14.73 ; bcp(2)+31.24 ] ;
p(:,end+1) = [ bcp(1)-13.72 ; bcp(2)+32.26 ] ;
p(:,end+1) = [ bcp(1)+13.72 ; bcp(2)+32.26 ] ;
p(:,end+1) = [ bcp(1)+14.73 ; bcp(2)+31.24 ] ;
p(:,end+1) = [ bcp(1)+14.73 ; bcp(2)-31.24 ] ;
p(:,end+1) = [ bcp(1)+13.72 ; bcp(2)-32.26 ] ;
if ( use_ignd != 0 )
  CSX = AddMaterial( CSX, 'sub_core' ) ;
  CSX = SetMaterialProperty( CSX, 'sub_core', 'Epsilon', sub.core_er, 'Kappa', sub.core_kappa ) ;
  CSX = AddLinPoly( CSX, 'sub_core', 1, 'z',
    sub.pp_thickness, p, sub.core_thickness ) ; % substrate core
  CSX = AddMaterial( CSX, 'sub_pp' ) ;
  CSX = SetMaterialProperty( CSX, 'sub_pp', 'Epsilon', sub.pp_er, 'Kappa', sub.pp_kappa ) ;
  CSX = AddLinPoly( CSX, 'sub_pp', 1, 'z',
    0, p, sub.pp_thickness ) ; % substrate pp bottom
  CSX = AddLinPoly( CSX, 'sub_pp', 1, 'z',
    sub.pp_thickness+sub.core_thickness, p, sub.pp_thickness ) ; % substrate pp top
else
  CSX = AddMaterial( CSX, 'substrate' ) ;
  CSX = SetMaterialProperty( CSX, 'substrate', 'Epsilon', sub.core_er, 'Kappa', sub.core_kappa ) ;
  CSX = AddLinPoly( CSX, 'substrate', 1, 'z', 0, p, sub.thickness ) ; % substrate core only
endif

% create solder mask with the same polygon of the substrate
CSX = AddMaterial( CSX, 'mask') ;
CSX = SetMaterialProperty( CSX, 'mask', 'Epsilon', mask.er, 'Kappa', mask.kappa ) ;
CSX = AddLinPoly( CSX, 'mask', 2, 'z', -mask.thickness, p, mask.thickness ) ; % bottom solder mask
CSX = AddLinPoly( CSX, 'mask', 2, 'z', sub.thickness, p, mask.thickness ) ; % top solder mask

% create enclosure based on the polygon of the substrate
if ( use_enclosure != 0 )
  % generate enclosure dimensions from substrate polygon
  enc.min_x = min( p( 1,1:end ) ) ;
  enc.max_x = max( p( 1,1:end ) ) ;
  enc.min_y = min( p( 2,1:end ) ) ;
  enc.max_y = max( p( 2,1:end ) ) ;
  p =          [ enc.min_x-enc.distance ; enc.min_y-enc.distance ] ;
  p(:,end+1) = [ enc.min_x-enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance ; enc.min_y-enc.distance ] ;
  CSX = AddMaterial( CSX, 'enclosure' ) ;
  CSX = SetMaterialProperty( CSX, 'enclosure', 'Epsilon', enc.er, 'Kappa', enc.kappa ) ;
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z', enc.distance, p, enc.thickness ) ; % top panel
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z',
    sub.thickness-enc.thickness-enc.distance, p, enc.thickness ) ; % bottom panel
  p =          [ enc.min_x-enc.distance ; enc.min_y-enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance ; enc.min_y-enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance+enc.thickness ; enc.min_y-enc.distance-enc.thickness ] ;
  p(:,end+1) = [ enc.min_x-enc.distance-enc.thickness ; enc.min_y-enc.distance-enc.thickness ] ;
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z',
    sub.thickness-enc.thickness-enc.distance, p,
    2*enc.distance+2*enc.thickness-sub.thickness ) ; % back panel
  p =          [ enc.min_x-enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance+enc.thickness ; enc.max_y+enc.distance+enc.thickness ] ;
  p(:,end+1) = [ enc.min_x-enc.distance-enc.thickness ; enc.max_y+enc.distance+enc.thickness ] ;
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z',
    sub.thickness-enc.thickness-enc.distance, p,
    2*enc.distance+2*enc.thickness-sub.thickness ) ; % front panel
  p =          [ enc.min_x-enc.distance ; enc.min_y-enc.distance ] ;
  p(:,end+1) = [ enc.min_x-enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.min_x-enc.distance-enc.thickness ; enc.max_y+enc.distance+enc.thickness ] ;
  p(:,end+1) = [ enc.min_x-enc.distance-enc.thickness ; enc.min_y-enc.distance-enc.thickness ] ;
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z',
    sub.thickness-enc.thickness-enc.distance, p,
    2*enc.distance+2*enc.thickness-sub.thickness ) ; % left panel
  p =          [ enc.max_x+enc.distance ; enc.min_y-enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance ; enc.max_y+enc.distance ] ;
  p(:,end+1) = [ enc.max_x+enc.distance+enc.thickness ; enc.max_y+enc.distance+enc.thickness ] ;
  p(:,end+1) = [ enc.max_x+enc.distance+enc.thickness ; enc.min_y-enc.distance-enc.thickness ] ;
  CSX = AddLinPoly( CSX, 'enclosure', 1, 'z',
    sub.thickness-enc.thickness-enc.distance, p,
    2*enc.distance+2*enc.thickness-sub.thickness ) ; % right panel
  enc_mesh.x = [ enc_mesh.x enc.min_x-enc.distance-enc.thickness/2 enc.max_x+enc.distance+enc.thickness/2 ] ;
  enc_mesh.y = [ enc_mesh.y enc.min_y-enc.distance-enc.thickness/2 enc.max_y+enc.distance+enc.thickness/2 ] ;
  enc_mesh.z = [ enc_mesh.z +sub.thickness-enc.distance-enc.thickness/2 enc.distance+enc.thickness/2 ] ;
endif

if ( debug_ant_mesh == 4 ) % show manual antenna mesh without smoothing
  mesh.x = [ mesh.x ant_mesh.x ] ;
  mesh.y = [ mesh.y ant_mesh.y ] ;
  mesh.z = [ mesh.z ant_mesh.z ant_mesh_t.z ant_mesh_b.z ant_mesh_i1.z ant_mesh_i2.z ] ;
elseif ( debug_ant_mesh == 3 ) % show all manual meshes without smoothing
  mesh.x = [ mesh.x ant_mesh.x via_mesh_l.x via_mesh_r.x shield_mesh.x enc_mesh.x ] ;
  mesh.y = [ mesh.y ant_mesh.y via_mesh_l.y via_mesh_r.y shield_mesh.y enc_mesh.y ] ;
  mesh.z = [ mesh.z ant_mesh.z ant_mesh_t.z ant_mesh_b.z ant_mesh_i1.z ant_mesh_i2.z shield_mesh.z enc_mesh.z ] ;
else
  if ( ant.th > 0 )
    ant_mesh.z = [ ant_mesh.z SmoothMeshLines( [ ant_mesh_t.z ant_mesh_i1.z ], mres_z ) ] ;
    ant_mesh.z = [ ant_mesh.z SmoothMeshLines( [ ant_mesh_b.z ant_mesh_i2.z ], mres_z ) ] ;
  endif
  mesh.x = [ mesh.x SmoothMeshLines( [ ant_mesh.x via_mesh_l.x via_mesh_r.x ], mres ) ] ;
  mesh.y = [ mesh.y SmoothMeshLines( [ ant_mesh.y via_mesh_l.y via_mesh_r.y ], mres ) ] ;
  mesh.z = [ mesh.z SmoothMeshLines( [ ant_mesh.z ], mres ) ] ;
  mesh.x = [ mesh.x SmoothMeshLines( shield_mesh.x, shres ) ] ;
  mesh.y = [ mesh.y SmoothMeshLines( shield_mesh.y, shres ) ] ;
  mesh.z = [ mesh.z SmoothMeshLines( shield_mesh.z, shres_z ) ] ;
  mesh.x = [ mesh.x enc_mesh.x ] ;
  mesh.y = [ mesh.y enc_mesh.y ] ;
  mesh.z = [ mesh.z enc_mesh.z ] ;
  if ( debug_ant_mesh <= 1 )
    % finalize the mesh
    mesh = SmoothMesh( mesh, sbres ) ; % 'debug', 1
  endif
endif

% apply the excitation & resist as a current source
stop = tfp + [ ant.exc_width  -ant.exc_depth  ant.thb ] ;
[CSX port] = AddLumpedPort( CSX, 5 ,1 ,ant.impedance, tfp, stop, [0 1 0], true ) ;

disp( [ 'Max mres: ' num2str(max_mres) ' mres: ' num2str(mres) ' mres_z: ' num2str(mres_z) ] ) ;
disp( [ 'Max shres: ' num2str(max_shres) ' shres: ' num2str(shres) ' shres_z: ' num2str(shres_z) ] ) ;
disp( [ 'Max sbres: ' num2str(max_sbres) ' sbres: ' num2str(sbres) ] ) ;

% generate a smooth mesh with max. cell size: lambda_min / 20
%mesh = DetectEdges(CSX, mesh); % order mesh items
%mesh = SmoothMesh(mesh, c0 / (f0+fc) / unit / 20);
CSX = DefineRectGrid( CSX, unit, mesh ) ;

%% add a nf2ff calc box; size is 3 cells away from MUR boundary condition
if ( size( mesh.x, 2 ) >= 4 && size( mesh.y, 2 ) >= 4 && size( mesh.z, 2 ) >= 4 )
  start = [mesh.x(4)     mesh.y(4)     mesh.z(4)];
  stop  = [mesh.x(end-3) mesh.y(end-3) mesh.z(end-3)];
  [CSX nf2ff] = CreateNF2FFBox( CSX, 'nf2ff', start, stop ) ;
endif

%% prepare simulation folder
Sim_Path = 'tmp_ant';
Sim_CSX = 'ant.xml';

try confirm_recursive_rmdir(false,'local'); end

[status, message, messageid] = rmdir( Sim_Path, 's' ); % clear previous directory
[status, message, messageid] = mkdir( Sim_Path ); % create empty simulation folder

%% write openEMS compatible xml-file
WriteOpenEMS( [Sim_Path '/' Sim_CSX], FDTD, CSX );

%% show the structure
CSXGeomPlot( [Sim_Path '/' Sim_CSX] ) ;

if ( debug_ant_mesh != 0 )
  return ;
endif

%% run openEMS
RunOpenEMS( Sim_Path, Sim_CSX ) ; %RunOpenEMS( Sim_Path, Sim_CSX, '--debug-PEC -v');
%RunOpenEMS( Sim_Path, Sim_CSX, '--debug-PEC --no-simulation' ); return;

system( "mpv ~/Rooster-SoundBible.com-1114473528.mp3 > /dev/null 2>&1" ) ;

%% postprocessing & do the plots
freq = linspace( max([1e9,f0-fc]), f0+fc, 501 ) ;
port = calcPort( port, Sim_Path, freq ) ;

Zin = port.uf.tot ./ port.if.tot ;
s11 = port.uf.ref ./ port.uf.inc ;
P_in = real( 0.5 * port.uf.tot .* conj( port.if.tot ) ) ; % antenna feed power

% plot feed point impedance
figure
plot( freq/1e6, real(Zin), 'k-', 'Linewidth', 2 );
hold on
grid on
plot( freq/1e6, imag(Zin), 'r--', 'Linewidth', 2 );
title( 'feed point impedance' );
xlabel( 'frequency f / MHz' );
ylabel( 'impedance Z_{in} / Ohm' );
legend( 'real', 'imag' );

% plot reflection coefficient S11
figure
plot( freq/1e6, 20*log10(abs(s11)), 'k-', 'Linewidth', 2 );
grid on
title( 'reflection coefficient S_{11}' );
xlabel( 'frequency f / MHz' );
ylabel( 'reflection coefficient |S_{11}|' );

%% Smith chart port reflection
plotRefl( port, 'threshold', -10 ) ;
title( 'reflection coefficient' ) ;

drawnow

%% NFFF contour plots %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%find resonance frequncy from s11
f_res_ind = find( s11 == min( s11 ) ) ; % find the index of resonant frequency
f_res = freq( f_res_ind ) ; % pick a frequency value by its index from array

%% Calculate 3D pattern
disp( 'calculating 3D far field pattern and dumping to vtk (use Paraview to visualize)...' );
thetaRange = ( 0 : 5 : 360 ) - 180 ;
phiRange = ( 0 : 5 : 360 ) - 180 ;
nf2ff = CalcNF2FF( nf2ff, Sim_Path, f_res, thetaRange*pi/180, phiRange*pi/180,'Verbose',2,'Outfile','3D_Pattern.h5' ) ;

% conventional plot approach
% plot( nf2ff.theta*180/pi, 20*log10(nf2ff.E_norm{1}/max(nf2ff.E_norm{1}(:)))+10*log10(nf2ff.Dmax));
%set( gca, 'visible', 'on' ) ; % visible axes
%xlabel_handle = get( gca, 'xlabel' ) ;
%current_xlabel = get( xlabel_handle, 'string' ) ;

% xy-plane looking from +z
figure % normalized directivity as polar plot
polarFF( nf2ff, 'xaxis', 'phi', 'param', [ find( thetaRange == 90 ) ], 'normalize', 1 ) ;
title_handle = get( gca, 'title' ) ; % gca is current axes handle
current_title = get( title_handle, 'string' ) ;
title( { current_title ; 'xy-plane looking into antenna from +z (pcb top)' } ) ;
text( -1.05, 0, '-x', 'horizontalalignment', 'right' ) ;
text( 0, -1.05, '-y', 'verticalalignment', 'top' ) ;
figure % log-scale directivity plot
plotFFdB( nf2ff, 'xaxis', 'phi', 'param', [ find( thetaRange == 90 ) ] ) ;
% xz-plane looking from +y
figure % normalized directivity as polar plot
polarFF( nf2ff, 'xaxis', 'theta', 'param', [ find( phiRange == 0 ) ], 'normalize', 1 ) ;
title_handle = get( gca, 'title' ) ; % gca is current axes handle
current_title = get( title_handle, 'string' ) ;
title( { current_title ; 'xz-plane looking into antenna from +y' } ) ;
text( -1.05, 0, '-z', 'horizontalalignment', 'right' ) ;
text( 0, -1.05, '-x', 'verticalalignment', 'top' ) ;
figure % log-scale directivity plot
plotFFdB( nf2ff, 'xaxis', 'theta', 'param', [ find( phiRange == 0 ) ] ) ;
% yz-plane looking from -x
figure % normalized directivity as polar plot
polarFF( nf2ff, 'xaxis', 'theta', 'param', [ find( phiRange == 90 ) ], 'normalize', 1 ) ;
title_handle = get( gca, 'title' ) ; % gca is current axes handle
current_title = get( title_handle, 'string' ) ;
title( { current_title ; 'yz-plane looking into antenna from -x (pcb edge from left)' } ) ;
text( -1.05, 0, '-z', 'horizontalalignment', 'right' ) ;
text( 0, -1.05, '-y', 'verticalalignment', 'top' ) ;
figure % log-scale directivity plot
plotFFdB( nf2ff, 'xaxis', 'theta', 'param', [ find( phiRange == 90 ) ] ) ;
drawnow

%% Calculate 3D pattern
%disp( 'calculating 3D far field pattern and dumping to vtk (use Paraview to visualize)...' );
%thetaRange = (0:2:180);
%phiRange = (0:2:360) - 180;
%nf2ff = CalcNF2FF(nf2ff, Sim_Path, f_res, thetaRange*pi/180, phiRange*pi/180,'Verbose',2,'Outfile','3D_Pattern.h5');

figure
plotFF3D( nf2ff ) ;
axis on

% display power and directivity
disp( ['radiated power: Prad = ' num2str(nf2ff.Prad) ' Watt']);
disp( ['directivity: Dmax = ' num2str(nf2ff.Dmax) ' (' num2str(10*log10(nf2ff.Dmax)) ' dBi)'] );
disp( ['efficiency: nu_rad = ' num2str(100*nf2ff.Prad./real(P_in(f_res_ind))) ' %']);

E_far_normalized = nf2ff.E_norm{1} / max(nf2ff.E_norm{1}(:)) * nf2ff.Dmax;
DumpFF2VTK([Sim_Path '/3D_Pattern.vtk'],E_far_normalized,thetaRange,phiRange,1e-3);

disp( [ "Ended: "  datestr(clock()) ] ) ;
%cd(current_path);
