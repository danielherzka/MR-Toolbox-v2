function PZ_tool(varargin)
%function PZ_tool(varargin);
% Pan - Zoom Tool to be used with imagescn. 
% Usage: Pz_tool;
%
% Author: Daniel Herzka  herzkad@nih.gov
% Laboratory of Cardiac Energetics 
% National Heart, Lung and Blood Institute, NIH, DHHS
% Bethesda, MD 20892
% and 
% Medical Imaging Laboratory
% Department of Biomedical Engineering
% Johns Hopkins University Schoold of Medicine
% Baltimore, MD 21205

% Updated: Daniel Herzka, 2017-02 -> .v0
% Cardiovascular Intervention Program
% National Heart, Lung and Blood Institute, NIH, DHHS
% Bethesda, MD 20892

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
% Lobby Function


if isempty(varargin) 
   Action = 'New';
else
   Action = varargin{1};  
end

% Set or clear global debug flag
global DB; DB = 1;

switch Action
    case 'New', 	                     Create_New_Objects;
    case 'Activate_PZ',                  Activate_PZ;
    case 'Deactivate_PZ',                Deactivate_PZ(varargin{2:end});
    case 'Adjust_On',                    Turn_Adjust_Pan_On;     % Entry
    case 'Adjust_Pan',                   Adjust_Pan;             % Cycle
    case 'Adjust_Pan_For_All',           Adjust_Pan_For_All;     % Exit
    case 'Switch_PZ',                    Switch_PZ;
    case 'Zoom',                         Apply_Zoom_Factor;
    case 'Done_Zoom',                    Done_Zoom;
    case 'PZ_Reset',                     PZ_Reset;
    case 'Auto_PZ_Reset',                Auto_PZ_Reset;
    case 'Menu_PZ',                      Menu_PZ;
    case 'Key_Press_CopyPaste',          Key_Press_CopyPaste(varargin{2:end});       
    case 'Close_Parent_Figure',          Close_Parent_Figure(varargin{2:end});    
    case 'Close_Request_Callback',       Close_Request_Callback;
    otherwise
        disp(['Unimplemented Functionality: ', Action]);
       
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Create_New_Objects
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

hUtils = MR_Toolbox_Utilities;

hFig = gcf;

objNames = retrieveNames;

% Create button
[hButton, hToolbar] = hUtils.createButtonObject(hFig, ...
    makeButtonImage, ...
    'PZ_tool(''Activate_PZ'');', ...
    'PZ_tool(''Deactivate_PZ'');',...
    objNames.buttonTag, ...
    objNames.buttonToolTipString);

% Create menu item
hMenu  = hUtils.createMenuObject(hFig,...
    objNames.menuTag, ...
    objNames.menuLabel, ...
    @Menu_PZ);

if ~isempty(hButton)
    aD.hUtils    =  hUtils;
    aD.hRoot     =  groot;
    aD.hFig      =  hFig;
    aD.hButton   =  hButton;
    aD.hMenu     =  hMenu;
    aD.hToolbar  =  hToolbar;
    aD.objectNames = objNames;
    
    % store app data structure
    storeAD(aD);
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Activate_PZ
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

%% PART I - Environment

aD = getAD;
    
% Check the menu object
if ~isempty(aD.hMenu), aD.hMenu.Checked = 'on'; end

% Find toolbar and deactivate other buttons
aD.hToolbar = findall(aD.hFig, 'type', 'uitoolbar');
aD.hToolbar = findobj(aD.hToolbar, 'Tag', 'FigureToolBar');

if ~isempty(aD.hToolbar)
    [aD.hToolbarChildren, aD.origToolEnables, aD.origToolStates ] = ...
        disableToolbarButtons(aD.hToolbar, aD.objectNames.buttonTag);
end;

% Store initial state of all axes in current figure for reset
aD.hAllAxes = flipud(findobj(aD.hFig,'Type','Axes'));
allXlims = zeros(length(aD.hAllAxes),2);
allYlims = zeros(length(aD.hAllAxes),2);
for i = 1:length(aD.hAllAxes)
    allXlims(i,:) = aD.hAllAxes(i).XLim;
    allYlims(i,:) = aD.hAllAxes(i).YLim;
end;

% Obtain current axis
aD.hRoot.CurrentFigure = aD.hFig;
aD.hCurrentAxes=aD.hFig.CurrentAxes;
if isempty(aD.hCurrentAxes), 
    aD.hCurrentAxes = aD.hAllAxes(1); 
    aD.hFig.CurrentAxes = aD.hCurrentAxes;
end;

% Store the figure's old infor within the fig's own userdata
aD.origProperties = retreiveOrigData(aD.hFig);

% Find and close the old PZ figure to avoid conflicts
hToolFigOld = findHiddenObj(aD.hRoot.Children, 'Tag', aD.objectNames.figTag);
if ~isempty(hToolFigOld), close(hToolFigOld); end;
pause(0.5);

% Make it easy to find this button (tack on 'On') 
% Wait until after old fig is closed.
aD.hButton.Tag = [aD.hButton.Tag,'_On'];
aD.hMenu.Tag   = [aD.hMenu.Tag, '_On'];
aD.hFig.Tag      = aD.objectNames.activeFigureName; % ActiveFigure

aD.hFig.WindowButtonDownFcn   = 'PZ_tool(''Adjust_On'');'; %entry
aD.hFig.WindowButtonUpFcn     = 'PZ_tool(''Adjust_Pan_For_All'');'; %exit
aD.hFig.WindowButtonMotionFcn = '';  
aD.hFig.WindowKeyPressFcn  = @Key_Press_CopyPaste;

% Draw faster and without flashes
aD.hFig.CloseRequestFcn = @Close_Parent_Figure;
aD.hFig.Renderer = 'zbuffer';
aD.hRoot.CurrentFigure = aD.hFig;
[aD.hAllAxes.SortMethod] = deal('Depth');

%% PART II Create GUI Figure
aD.hToolFig = openfig(aD.objectNames.figFilename,'reuse');

% Enable save_prefs tool button
if ~isempty(aD.hToolbar)
    aD.hSP = findobj(aD.hToolbarChildren, 'Tag', 'figSavePrefsTool');
    aD.hSP.Enable = 'On';
    optionalUIControls = {'Apply_radiobutton', 'Value'};
    aD.hSP.UserData = {aD.hToolFig, aD.objectNames.figFilename, optionalUIControls};
end

% Generate a structure of handles to pass to callbacks, and store it. 
aD.hGUI = guihandles(aD.hToolFig);

aD.hToolFig.Name = aD.objectNames.figName;
aD.hToolFig.CloseRequestFcn = @Close_Request_Callback;

%%  PART III - Finish setup for other objects
% Change the pointer and store the old pointer data
[openHandPointerImage, closedHandPointerImage ] =  definePointers;
aD.hFig.Pointer =  'Custom';
aD.hFig.PointerShapeCData = openHandPointerImage;

hIm = findobj(aD.hCurrentAxes, 'Type', 'Image');
imCData = hIm.CData;
zoom_factor = max([size(imCData,2)/diff(allXlims(aD.hCurrentAxes==aD.hAllAxes,:)),...
    size(imCData,1)/diff(allYlims(aD.hCurrentAxes==aD.hAllAxes,:))]);

% Store all relevant info for faster use during calls
%hGUI.Reset_pushbutton.UserData =  {hFig, hToolFig, hAllAxes, all_xlims, all_ylims, hAxes };
aD.hGUI.Reset_pushbutton.Enable = 'Off';
aD.hGUI.Zoom_value_edit.String  = num2str(zoom_factor,3);

% Store application data within the button
aD.closedHandPointerImage = closedHandPointerImage;
aD.openHandPointerImage = openHandPointerImage;
aD.origXLims = allXlims;
aD.origYLims = allYlims;
aD.copy.XLim  = [];
aD.copy.YLim  = [];

storeAD(aD);

Switch_PZ;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Deactivate_PZ
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

aD = getAD;
if ~isempty(aD.hButton)
    aD.hButton.Tag = aD.hButton.Tag(1:end-3);
end
    
if ~isempty(aD.hMenu)
    aD.hMenu.Checked = 'off';
    aD.hMenu.Tag = aD.hMenu.Tag(1:end-3);
end
   
% Close PZ figure
delete(aD.hToolFig);

zoom off;
dispDebug('Zoom off');

% Restore old BDFs
aD.hUtils.restoreOrigData(aD.hFig, aD.origProperties);

% Reactivate other buttons
aD.hUtils.enableToolbarButtons(aD.hToolbarChildren, aD.origToolEnables, aD.origToolStates )
 

%Disable save_prefs tool button
if ishghandle(aD.hSP)
    aD.hSP.Enable = 'Off';
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Turn_Adjust_Pan_On
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

% Execute once at the beggining of a drag cycle
aD = getAD;

if strcmp(aD.hFig.SelectionType,'normal')
    
    aD.hFig.WindowButtonMotionFcn = @Adjust_Pan; % two inputs
    %aD.hFig.WindowButtonMotionFcn = 'PZ_tool(''Adjust_Pan'');';
    
    % change the pointer to closed hand
    aD.hFig.PointerShapeCData = aD.closedHandPointerImage;
    
    aD.hFig.CurrentAxes = gca;
    point = aD.hFig.CurrentAxes.CurrentPoint;
    aD.ReferencePoint = [point(1,1) point(1,2)];
    
    storeAD(aD);
    
    Adjust_Pan;
else
    dispDebug('alternate selection');
end

dispDebug('end');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Adjust_Pan(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug

aD = getAD; 

aD.hCurrentAxes = gca;
currPoint = aD.hCurrentAxes.CurrentPoint;
refPoint = aD.ReferencePoint;

xlim = aD.hCurrentAxes.XLim;
ylim = aD.hCurrentAxes.YLim;

% Use fraction  i.e. relative to position to the originally clicked point
% to determine the change in window and level
deltas = currPoint(1,1:2) - refPoint;

xlim = xlim - deltas(1);
ylim = ylim - deltas(2);

% set the xlims and the ylims after motion
aD.hCurrentAxes.XLim = xlim;
aD.hCurrentAxes.YLim = ylim;

storeAD(aD);

dispDebug('end');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Adjust_Pan_For_All
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Execute once after panning is done
% Check to see if all images in slice should be rescaled
dispDebug;

aD = getAD;
aD.hFig.WindowButtonMotionFcn = ' ';

apply_all = aD.hGUI.Apply_radiobutton.Value;
%most_current_data = hGUI.Apply_radiobutton.UserData

currentXLim = aD.hCurrentAxes.XLim;
currentYLim = aD.hCurrentAxes.YLim;

if apply_all
    [aD.hAllAxes.XLim] =  deal(currentXLim);
    [aD.hAllAxes.YLim] =  deal(currentYLim);
end;

aD.hFig.PointerShapeCData = aD.openHandPointerImage;
aD.hGUI.Reset_pushbutton.Enable = 'On';

%figure(aD.hToolFig);
aD.hRoot.CurrentFigure = aD.hFig;
dispDebug('end');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Apply_Zoom_Factor
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

aD = getAD;

apply_all = aD.hGUI.Apply_radiobutton.Value;
zoom_factor = str2double(aD.hGUI.Zoom_value_edit.String);

% str2double returns NaN when it fails
if ~isnan(zoom_factor)
    
    if apply_all, all_axes = aD.hAllAxes;
    else          all_axes = aD.hCurrentAxes;
    end;
    
    hIm = findobj(aD.hCurrentAxes, 'Type', 'Image');
    im = hIm.CData;
    xsize = size(im,2);
    ysize = size(im,1);
    
    for i =1:length(all_axes)
        ax = all_axes(i).XLim;
        ay = all_axes(i).YLim;
        cx = mean(ax); cy = mean(ay);
        lx = (xsize)/zoom_factor/2;
        ly = (ysize)/zoom_factor/2;
        
        all_axes(i).XLim =  [-lx, lx] +cx;
        all_axes(i).YLim =  [-ly, ly] +cy;
    end;
    
    % save last axis with an action
    aD.hGUI.Reset_pushbutton.Enable = 'On';
    
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function PZ_Reset
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to reset the axes limits to whatever they were upon
% startup of the tool
dispDebug('end');

aD = getAD;
apply_all = aD.hGUI.Apply_radiobutton.Value;

if isempty(aD.hFig.CurrentAxes)
    aD.hFig.CurrentAxes = hAllAxes(1);
end
aD.hCurrentAxes = aD.hFig.CurrentAxes;
    
hAxes_idx = find(aD.hAllAxes==aD.hCurrentAxes);


aD.hCurrentAxes.XLim = aD.origXLims(hAxes_idx,:);
aD.hCurrentAxes.YLim = aD.origYLims(hAxes_idx,:);

if apply_all,
    for i = 1:length(aD.hAllAxes)
        aD.hAllAxes(i).XLim = aD.origXLims(i,:);
        aD.hAllAxes(i).YLim = aD.origYLims(i,:);
    end;
    aD.hGUI.Reset_pushbutton.Enable = 'Off';
end

hIm = findobj(aD.hCurrentAxes, 'Type', 'image');
im = hIm.CData;

zoom_factor_x = size(im,2) / diff(aD.hCurrentAxes.XLim);
zoom_factor_y = size(im,1) / diff(aD.hCurrentAxes.YLim);

aD.hGUI.Zoom_value_edit.String = num2str(max([zoom_factor_x, zoom_factor_y]),3);
aD.hRoot.CurrentFigure = aD.hFig;

storeAD(aD);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Auto_PZ_Reset
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to automatically set the limits - ie use the complete
% cdata 
dispDebug;

aD = getAD;
apply_all = aD.hGUI.Apply_radiobutton.Value;

if ~isempty(aD.hFig.CurrentAxes)
    aD.hCurrentAxes = aD.hFig.CurrentAxes;
else
    aD.hCurrentAxes = aD.hAllAxes(1);
end

aD.hRoot.CurrentFigure = aD.hFig;

aD.hCurrentAxes.XLimMode = 'auto';
aD.hCurrentAxes.YLimMode = 'auto';
axis('image');

if apply_all    
    for i = 1:length( aD.hAllAxes)
        aD.hFig.CurrentAxes = aD.hAllAxes(i);
        aD.hAllAxes(i).XLimMode = 'auto';
        aD.hAllAxes(i).YLimMode = 'auto';
        axis('image');
    end;
end
aD.hFig.CurrentAxes = aD.hCurrentAxes;
aD.hGUI.Zoom_value_edit.String = num2str(1);
aD.hGUI.Reset_pushbutton.Enable = 'On';
aD.hRoot.CurrentFigure = aD.hFig;

storeAD(aD);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Switch_PZ
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% switch between active panning (default case) and active zooming via zoom on;
% only change to zooming is the fact that we decide to keep a square axis at 
% all times so an extra step to the windowbuttonupfcn is appended.
dispDebug;

aD = getAD;

Pan_On   = aD.hGUI.Pan_radiobutton.Value;
Zoom_On  = aD.hGUI.Zoom_radiobutton.Value;

hCurrentRadiobutton = gcbo;

if strcmp(hCurrentRadiobutton.Tag, 'Pan_radiobutton')
    % pan button was last to be used
    if Pan_On,  Panning = 1;
    else        Panning = 0;
    end;
else
    % zoom button was last to be used (or no button was used)
    if Zoom_On, Panning = 0;
    else        Panning = 1;
    end;
end;

Zooming = ~Panning;
aD.hGUI.Pan_radiobutton.Value =  Panning;
aD.hGUI.Zoom_radiobutton.Value = Zooming;

aD.hRoot.CurrentFigure = aD.hFig;

if Panning
    dispDebug('Zoom off')
    if ~isfield(aD, 'hZoom')
        aD.hZoom=zoom;
    end
        
    aD.hZoom.ActionPostCallback = [];
    aD.hZoom.Enable = 'off';
    aD.hZoom.RightClickAction = 'PostContextMenu';
    aD.hFig.Pointer = 'Custom';
elseif Zooming
    dispDebug('Zoom on')
       
    if ~isfield(aD, 'hZoom')
        aD.hZoom=zoom;
    end
    aD.hZoom.ActionPostCallback = @Done_Zoom; % must send function handle
    aD.hZoom.Enable = 'on';
    aD.hZoom.RightClickAction = 'PostContextMenu';
    aD.hFig.Pointer= 'Arrow'; 
end;

storeAD(aD);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Done_Zoom(~,~)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

aD = getAD;

% Update current axes
if isempty(aD.hFig.CurrentAxes)
    aD.hFig.CurrentAxes = aD.hAllAxes(1);
end
aD.hCurrentAxes = aD.hFig.CurrentAxes;

hIm = findobj(aD.hCurrentAxes, 'Type', 'image');
im = hIm.CData;

% Ta daa
%axis('equal');
xlim = aD.hCurrentAxes.XLim;
ylim = aD.hCurrentAxes.YLim;

zoom_factor_x = size(im,2) / diff(xlim);
zoom_factor_y = size(im,1) / diff(ylim);

aD.hGUI.Zoom_value_edit.String = num2str(max([zoom_factor_x, zoom_factor_y]),3);

% now check if we need to apply new limits to all axes
apply_all = aD.hGUI.Apply_radiobutton.Value;

if apply_all
    [aD.hAllAxes.XLim] = deal(xlim);
    [aD.hAllAxes.YLim] = deal(ylim);
end;

figure(aD.hToolFig);

aD.hGUI.Reset_pushbutton.Enable = 'On';
aD.hRoot.CurrentFigure = aD.hFig;

storeAD(aD);

dispDebug('end');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Menu_PZ(~,~)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
aD = getAD;
aD.hUtils.menuToggle(aD.hMenu,aD.hButton);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Key_Press_CopyPaste(~, data)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

aD = getAD;

switch data.Key
    case 'c' %copy
        aD.copy.XLim = aD.hCurrentAxes.XLim;
        aD.copy.YLim = aD.hCurrentAxes.YLim;
        storeAD(aD);
    case {'p','v'} %paste
        apply_all = aD.hGUI.Apply_radiobutton.Value;
        if ~isempty(aD.copy.XLim)
            if apply_all
                [aD.hAllAxes.XLim ]= deal(aD.copy.XLim);
                [aD.hAllAxes.YLim ]= deal(aD.copy.YLim);
            else
                aD.hCurrentAxes.XLim = aD.copy.XLim;
                aD.hCurrentAxes.YLim = aD.copy.YLim;
            end
        end
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Close_Request_Callback(varargin)
% using function handle for callback -> two input arguments are necessary
dispDebug;

aD = getAD;

old_SHH = aD.hRoot.ShowHiddenHandles;
aD.hRoot.ShowHiddenHandles = 'On';

%call->PZ_tool('Deactivate_PZ');
aD.hButton.State = 'off';

aD.hRoot.ShowHiddenHandles= old_SHH;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%% 
%
function Close_Parent_Figure(hFig,~)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to make sure that if parent figure is closed, 
% the tool figure is also closed
dispDebug;

aD = getAD;
if ~isempty(aD)
    hToolFig = aD.hToolFig;
else
    % Parent Figure is already closed and aD is gone
    dispDebug('ParFig closed!');
    objNames = retrieveNames;
    hToolFig = findobj(groot, 'Tag', objNames.figTag); 
end


hToolFig.CloseRequestFcn = 'closereq';
try
    close(hToolFig);
catch
    delete(hToolFig);
end;

hFig.CloseRequestFcn = 'closereq';
close(hFig);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%START LOCAL SUPPORT FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function h = findHiddenObj(Handle, Property, Value)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
h_root = groot;
old_SHH = h_root.ShowHiddenHandles;
h_root.ShowHiddenHandles = 'On';
if nargin <3
	h = findobj(Handle, Property);
else
	h = findobj(Handle, Property, Value);
end;
h_root.ShowHiddenHandles = old_SHH;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function [open_pointer_image, closed_pointer_image ] = definePointers
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the black and white parts for both the pointer shapes
% Repeat the last line to make the pointer data 16x16
dispDebug;

f_black_open = [...
     8     9    22    25    33    34    37    41    42    47    50    51    53,...
    58    62    67    68    74    78    79    90    92    93    94    95    96,...
    97   106   121   137   138   139   140   141   142   152   167   183   184,...
   185   186   187   188   194   195   200   206   207   208   214   219   220,...
   221   230   231   232   233];

f_white_open =[...
    23    24    38    39    40    48    49    54    55    56    57    63    64,...
    65    66    69    70    71    72    73    80    81    82    83    84    85,...
    86    87    88    89    98    99   100   101   102   103   104   105   107,...
   108   109   110   111   112   113   114   115   116   117   118   119   120,...
   122   123   124   125   126   127   128   129   130   131   132   133   134,...
   135   143   144   145   146   147   148   149   150   153   154   155   156,...
   157   158   159   160   161   162   163   164   165   168   169   170   171,...
   172   173   174   175   176   177   178   179   180   189   190   191   192,...
   193   201   202   203   204   205   215   216   217   218];

f_black_closed = [...
    41    42    52    53    55    58    66    69    70    74    81    90    97,...
   111   126   142   156   171   187   188   194   195   202   206   207   208,...
   218   219   220   221];

f_white_closed = [...
    56    57    67    68    71    72    73    82    83    84    85    86    87,...
    88    89    98    99   100   101   102   103   104   105   112   113   114,...
   115   116   117   118   119   120   127   128   129   130   131   132   133,...
   134   135   143   144   145   146   147   148   149   150   157   158   159,...
   160   161   162   163   164   165   172   173   174   175   176   177   178,...
   179   180   189   190   191   192   193   203   204   205];

open_pointer_image = NaN*zeros(15,16);
open_pointer_image(f_black_open) = 1;
open_pointer_image(f_white_open) = 2;
open_pointer_image = cat(1,open_pointer_image,open_pointer_image(15,:)); 

closed_pointer_image = NaN*zeros(15,16);
closed_pointer_image(f_black_closed) = 1;
closed_pointer_image(f_white_closed) = 2;
closed_pointer_image = cat(1,closed_pointer_image,closed_pointer_image(15,:)); 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function button_image = makeButtonImage
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The default button size is 15 x 16 x 3.
dispDebug;

button_size_x= 16;
button_image = NaN* zeros(15,button_size_x);

f= [...
    8     9    22    25    33    34    37    41    42,...
    47    50    51    53    58    62    67    68    69,...
    74    78    79    90    92    93    94    95    96,...
    97   106   121   137   138   139   140   141   142,...
    152   167   183   184   185   186   187   188   194,...
    195   200   206   207   208   214   219   220   221,...
    230   231   232   233];

button_image(f) = 0;
button_image = repmat(button_image, [1,1,3]);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function [hToolbar_Children, origToolEnables, origToolStates ] = disableToolbarButtons(hToolbar, currentToolName)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

hRoot = groot;
old_SHH = hRoot.ShowHiddenHandles;
hRoot.ShowHiddenHandles = 'on';

hToolbar_Children = hToolbar.Children;

origToolEnables = cell(size(hToolbar_Children));
origToolStates  = cell(size(hToolbar_Children));


for i = 1:length(hToolbar_Children) 
    if ~strcmpi(hToolbar_Children(i).Tag, currentToolName)
        if isprop(hToolbar_Children(i), 'Enable')
            origToolEnables{i} =  hToolbar_Children(i).Enable;
            hToolbar_Children(i).Enable ='off';
        end
        if isprop(hToolbar_Children(i), 'State')
            origToolStates{i}  =  hToolbar_Children(i).State;
            hToolbar_Children(i).Enable ='off';
        end
    end
end

hRoot.ShowHiddenHandles = old_SHH;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function enableToolbarButtons(hToolbar_Children, origToolEnables, origToolStates)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

for i = 1:length(hToolbar_Children)
    if isprop(hToolbar_Children(i), 'Enable') && ~isempty(origToolEnables{i})
        hToolbar_Children(i).Enable = origToolEnables{i};
    end
    if isprop(hToolbar_Children(i), 'State') && ~isempty(origToolStates{i})
        hToolbar_Children(i).State = origToolStates{i};
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function structNames = retrieveNames
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
structNames.toolName            = 'PZ_tool';
structNames.buttonTag           = 'figPanZoom';
structNames.buttonToolTipString = 'Pan and Zoom Figure';
structNames.menuTag             = 'menuPanZoom';
structNames.menuLabel           = 'Pan and Zoom';
structNames.figFilename         = 'PZ_tool_figure.fig';
structNames.figName             = 'PZ Tool';
structNames.figTag              = 'PZ_figure';
structNames.activeFigureName    = 'ActiveFigure';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  storeAD(aD)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
setappdata(aD.hFig, 'PZData', aD);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  aD = getAD
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

% fastest way to find figure; doesn't work during Create
tic
aD = [];
hFig = findobj(groot, 'Tag', 'ActiveFigure'); %flat?


if isempty(hFig)
    % Call from Activate
    objNames = retrieveNames;
    obj = findHiddenObj('Tag', objNames.buttonTag);
    if ~isempty(obj)
        while ~strcmpi(obj.Type, 'Figure')
            obj = obj.Parent;
        end
        hFig = obj;
    end
end

if isappdata(hFig, 'PZData')
    aD = getappdata(hFig, 'PZData');
end
    
dispDebug(['end (',num2str(toc),')']);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function propList = retreiveOrigData(hFig)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrive previous settings for storage
dispDebug;

propList = {...
    'WindowButtonDownFcn'; ...
    'WindowButtonMotionFcn'; ...
    'WindowButtonUpFcn'; ...
    'WindowKeyPressFcn'; ...
    'UserData'; ...
    'CloseRequestFcn'; ...
    'Pointer'; ...
    'PointerShapeCData'; ...
    'Tag' ...
    };

for i = 1:size(propList,1)
    propList{i,2} = hFig.(propList{i,1});
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function restoreOrigData(hFig, propList)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Restore previous WBDF etc to restore state after WL is done.
dispDebug;
for i = 1:size(propList,1)
  hFig.(propList{i,1}) = propList{i,2};
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

function  dispDebug(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Print a debug string if global debug flag is set
global DB;

if DB
    objectNames = retrieveNames;
    x = dbstack;
    func_name = x(2).name;    loc = [];
    if length(x) > 4
        loc = [' (loc) ', repmat('|> ',1, length(x)-3)] ;
    end
    fprintf([objectNames.toolName, ':',loc , ' %s'], func_name);
    if nargin>0
        for i = 1:length(varargin)
            str = varargin{i};
            fprintf(': %s', str);
        end
    end
    fprintf('\n');
    
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Notes/ToDo
% UIContextemenu for copy/paste: what is the hit order/hierarchy? Why does
%  the uicontextmenu not show up during zoom function? During Pan?
% During recovery, should the tool come up with the exact previous state?
%  Could be implemented with get/setappdata functionality. I.e. when you
%  close the tool with Pan on, it should be on upon restart. Same for apply
%  scope.
% The creation of a utility suite (via str2fun) should make code accross
%  tools more general and more broadly applicable. Could make implementation
%  of new tools (2D or 3D registration, fitting of relaxation parameters)
%  easier and more robust.

