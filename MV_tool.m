function MV_tool(varargin)
% function MV_tool(varargin)
% Movie viewing tool for displaying 3D or 4D sets of data. Use with
% imagescn. Can export to avi.
% Usage: MV_tool;
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


if isempty(varargin) 
   Action = 'New';
else
   Action = varargin{1};  
end

% Set or clear global debug flag
global DB; DB = 1;

switch Action
    case 'New',                        Create_New_Objects;
    case 'Activate_MV',                Activate_MV;
    case 'Deactivate_MV',              Deactivate_MV(varargin{2:end});
    case 'Set_Current_Axes', 	       Set_Current_Axes(varargin{2:end});
    case 'Limit', 	                   Limit(varargin{2:end});
    case 'Step', 	                   Step(varargin{2:end});
    case 'Set_Frame', 	               Set_Frame;
    case 'Set_Frame_Limit',            Set_Frame_Limit;
    case 'Reset_Frame_Limit',          Reset_Frame_Limit;
    case 'Play_Movie',                 Play_Movie;
    case 'Stop_Movie',                 Stop_Movie;
    case 'Make_Movie',                 Make_Movie;
    case 'Show_Frames',                Show_Frames;
    case 'Show_Objects',               Show_Objects;
    case 'Toggle_Object',              Toggle_Object(varargin{2:end});
    case 'Menu_MV',                    Menu_MV(varargin{2:end});
    case 'Close_Parent_Figure',        Close_Parent_Figure(varargin{2:end});
    otherwise
        disp(['Unimplemented Functionality: ', Action]);
        
end;
      
%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Create_New_Objects
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

hUtils = MR_Toolbox_Utilities;

hFig = gcf;

objNames = retrieveNames;

%Create Button
[hButton, hToolbar] = hUtils.createButtonObject(hFig, ...
    makeButtonImage, ...
    'MV_tool(''Activate_MV'');', ...
    'MV_tool(''Deactivate_MV'');',...
    objNames.buttonTag, ...
    objNames.buttonToolTipString);

    
hMenu  = hUtils.createMenuObject(hFig,...
    objNames.menuTag, ...
    objNames.menuLabel, ...
    @Menu_MV);

% If button doesn't exist
if ~isempty(hButton)
    aD.hUtils      =  hUtils;
    aD.hRoot       =  groot;
    aD.hFig        =  hFig;
    aD.hButton     =  hButton;
    aD.hMenu       =  hMenu;
    aD.hToolbar    =  hToolbar;
    aD.objectNames =  objNames;
    
    storeAD(aD);
    
    hAllAxes = findobj(aD.hFig, 'Type', 'Axes');
    
    if isempty(getappdata(hAllAxes(1), 'CurrentImage'))
        % Current images do not have hidden dimension data
        % Assume if one axis has hidden dimension, all do.
        hButton.Enable=  'off';
        if ~isempty(hMenu), hMenu.Enable= 'Off'; end
    end;
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%	

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Activate_MV(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

%% PART I - Environment
aD = getAD;

if ~isempty(aD.hMenu), aD.hMenu.Checked = 'on'; end

aD.hToolbar = findall(aD.hFig, 'type', 'uitoolbar');
aD.hToolbar = findobj(aD.hToolbar, 'Tag', 'FigureToolBar');

if ~isempty(aD.hToolbar)
    [aD.hToolbarChildren, aD.origToolEnables, aD.origToolStates ] = ...
        aD.hUtils.disableToolbarButtons(aD.hToolbar,aD.objectNames.buttonTag);
  
    % Enable save_prefs tool button
    aD.hSP = findobj(aD.hToolbarChildren, 'Tag', 'figSavePrefsTool');
    aD.hSP.Enable = 'On';
end;

% Store initial state of all axes in current figure for reset
aD.hAllAxes = flipud(findobj(aD.hFig,'Type','Axes'));
aD.hAllImages = findAxesChildIm(aD.hAllAxes);

% Obtain current axis
aD.hRoot.CurrentFigure = aD.hFig;
aD.hCurrentAxes=aD.hFig.CurrentAxes;
if isempty(aD.hCurrentAxes), 
    aD.hCurrentAxes = aD.hAllAxes(1); 
    aD.hFig.CurrentAxes = aD.hCurrentAxes;
end;

% Store the figure's old infor within the fig's own userdata
aD.origProperties      = aD.hUtils.retrieveOrigData(aD.hFig);
aD.origAxesProperties  = aD.hUtils.retrieveOrigData(aD.hAllAxes , {'ButtonDownFcn'});
aD.origImageProperties = aD.hUtils.retrieveOrigData(aD.hAllImages , {'ButtonDownFcn'});

% Find and close the old WL figure to avoid conflicts
hToolFigOld = aD.hUtils.findHiddenObj(aD.hRoot.Children, 'Tag', aD.objectNames.figTag);
if ~isempty(hToolFigOld), close(hToolFigOld);end;
pause(0.5);

% Make it easy to find this button (tack on 'On') 
% Wait until after old fig is closed.
aD.hButton.Tag = [aD.hButton.Tag,'_On'];
aD.hMenuPZ.Tag   = [aD.hMenu.Tag, '_On'];
aD.hFig.Tag      = aD.objectNames.activeFigureName; % ActiveFigure
aD.hFig.CloseRequestFcn = @Close_Parent_Figure;

% Draw faster and without flashes
aD.hFig.Renderer = 'zbuffer';
aD.hRoot.CurrentFigure = aD.hFig;
[aD.hAllAxes.SortMethod] = deal('Depth');

%% PART II - Create GUI Figure
aD.hToolFig = openfig(aD.objectNames.figFilename,'reuse');

% Load Save preferences tool data
optionalUIControls = { ...
    'Apply_radiobutton',    'Value'; ...
    'Frame_Rate_edit',      'String'; ...
    'Make_Avi_checkbox',    'Value'; ...
    'Make_Mat_checkbox',    'Value'; ...
    'Show_Frames_checkbox', 'Value'; ... 
    };
aD.hSP.UserData = {aD.hToolFig, aD.objectNames.figFilename, optionalUIControls};

% Generate a structure of handles to pass to callbacks, and store it. 
aD.hGUI = guihandles(aD.hToolFig);

aD.hToolFig.Name = aD.objectNames.figName;
aD.hToolFig.CloseRequestFcn = @Close_Request_Callback;

%%  PART III - Finish setup for other objects
[aD.hAllAxes(:).ButtonDownFcn] = deal('MV_tool(''Set_Current_Axes'')');
aD.hRoot.CurrentFigure = aD.hFig;

% Add frame number to each axes
aD.hFrameNumbers = createFrameNumbers(aD.hFig, aD.hAllAxes, aD.hAllImages);
textVisibility = aD.hGUI.Show_Frames_checkbox.Value;
if textVisibility, textVisibility = 'On' ;
else               textVisibility = 'Off'; end;
[aD.hFrameNumbers(:).Visible] = deal(textVisibility);

aD.hFig.CurrentAxes = aD.hCurrentAxes;
aD.hRoot.CurrentFigure = aD.hToolFig;

aD.hGUI.Frame_Value_edit.String = num2str(getappdata(aD.hCurrentAxes,'CurrentImage'));	
aD.hObjects = []; 

storeAD(aD);

Set_Current_Axes(aD.hCurrentAxes);
%drawObjects(aD.hAllAxes);
%Show_Objects;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Deactivate_MV(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

global GLOBAL_STOP_MOVIE 
GLOBAL_STOP_MOVIE = 2;

aD = getAD;

if ~isempty(aD.hButton)
    aD.hButton.Tag = aD.hButton.Tag(1:end-3);
end

if ~isempty(aD.hMenu)
    aD.hMenu.Checked = 'off';
    aD.hMenu.Tag = aD.hMenu.Tag(1:end-3);
end

% Restore old figure settings
 aD.hUtils.restoreOrigData(aD.hFig, aD.origProperties);
 aD.hUtils.restoreOrigData(aD.hAllAxes, aD.origAxesProperties);
 aD.hUtils.restoreOrigData(aD.hAllImages, aD.origImageProperties);

% Reactivate other buttons
aD.hUtils.enableToolbarButtons(aD.hToolbarChildren, aD.origToolEnables, aD.origToolStates )

delete(aD.hFrameNumbers); % redrawn every call

% Close MV figure
delete(aD.hToolFig);

if ~isempty(aD.hObjects)
    delete(aD.hObjects(isgraphics(aD.hObjects))); % redrawn every call
end;

%Disable save_prefs tool button
if ishghandle(aD.hSP)
aD.SP.Enable = 'Off';
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Step(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

global GLOBAL_STOP_MOVIE;

if ~GLOBAL_STOP_MOVIE
	Stop_Movie;
end

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

if isempty(varargin);
	% mouse click, specify axis and function
	handlesMV.CurrentAxes = gca;
	selectiontype = get(handlesMV.ParentFigure, 'SelectionType');
	switch selectiontype 
		case 'normal'
			direction = 1;	
		case 'alt'
			direction = -1;
		case 'open'
			Play_Movie;
			return;
	end;
else
	% call from buttons
	direction = varargin{1};
end;

% specify single or all axes
CurrentAxes = handlesMV.CurrentAxes;
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	current_frame = getappdata(CurrentAxes(i), 'CurrentImage');
	image_range   = getappdata(CurrentAxes(i), 'ImageRange');
	image_data    = getappdata(CurrentAxes(i), 'ImageData');
        
	if     (current_frame + direction) > image_range(2), current_frame = image_range(1); 
	elseif (current_frame + direction) < image_range(1), current_frame = image_range(2); 
	else                                                 current_frame = current_frame + direction; end;
	
	setappdata(CurrentAxes(i), 'CurrentImage', current_frame);
	set(handlesMV.htFrameNumbers(find(handlesMV.Axes == CurrentAxes(i))), 'String', num2str(current_frame));
	set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', squeeze(image_data(:,:,current_frame)));
	if (handlesMV.CurrentAxes==CurrentAxes(i))
		% if doing the single current axes, update the 
		set(handlesMV.Frame_Value_edit, 'String', num2str(current_frame));	
		Set_Current_Axes(CurrentAxes(i));
        
	end;

    %%%CHUS%%%
    if ~isempty(handlesMV.ObjectHandles)
        % Objects Exist- update the xdata/ydata for each object
        object_data   = getappdata(CurrentAxes(i), 'Objects');
        Update_Object(object_data, handlesMV.ObjectHandles{find(handlesMV.Axes==CurrentAxes(i)),1},current_frame);
    end;
    %%%CHUS%%%
        

    
	figure(fig2);
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Limit(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

% call from buttons
direction = varargin{1};

% specify single or all axes
CurrentAxes = handlesMV.CurrentAxes;
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	image_range   = getappdata(CurrentAxes(i), 'ImageRange');
	image_data    = getappdata(CurrentAxes(i), 'ImageData');
	
	if direction == 1
		current_frame = image_range(2);
	elseif direction == -1
		current_frame = image_range(1);
	end;
	
	setappdata( CurrentAxes(i), 'CurrentImage', current_frame);
	set(handlesMV.htFrameNumbers(find(handlesMV.Axes == CurrentAxes(i))), 'String', num2str(current_frame));
	set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', squeeze(image_data(:,:,current_frame)));
	if (handlesMV.CurrentAxes==CurrentAxes(i))
		set(handlesMV.Frame_Value_edit, 'String', num2str(current_frame));	
		Set_Current_Axes(CurrentAxes(i));
	end;
           
    %%%CHUS%%%
    if ~isempty(handlesMV.ObjectHandles)
        object_data   = getappdata(CurrentAxes(i), 'Objects');
        Update_Object(object_data, handlesMV.ObjectHandles{find(handlesMV.Axes==CurrentAxes(i))},current_frame);
    end;
    %%%CHUS%%%
    
    
end;
figure(fig2);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Set_Frame
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

current_frame = str2num(get(handlesMV.Frame_Value_edit, 'String'));

% specify single or all axes
CurrentAxes = handlesMV.CurrentAxes;
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	image_range   = getappdata(CurrentAxes(i), 'ImageRange');
	image_data    = getappdata(CurrentAxes(i), 'ImageData');
	
	% Error check
	if current_frame > image_range(2), current_frame = image_range(2); end;
	if current_frame < image_range(1), current_frame = image_range(1); end;
	
	setappdata( CurrentAxes(i), 'CurrentImage', current_frame);
	set(handlesMV.htFrameNumbers(find(handlesMV.Axes == CurrentAxes(i))), 'String', num2str(current_frame));
	set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', squeeze(image_data(:,:,current_frame)));
	if (handlesMV.CurrentAxes==CurrentAxes(i))
		set(handlesMV.Frame_Value_edit, 'String', num2str(current_frame));	
		Set_Current_Axes(CurrentAxes(i));
	end;
                
    %%%CHUS%%%
    if ~isempty(handlesMV.ObjectHandles)
        object_data   = getappdata(CurrentAxes(i), 'Objects');
        
        % Objects Exist- update the xdata/ydata for each object 
        Update_Object(object_data, handlesMV.ObjectHandles{find(handlesMV.Axes==CurrentAxes(i)),1},current_frame);
            
    end;
    %%%CHUS%%%

end;
figure(fig2);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Set_Frame_Limit
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
CurrentAxes = handlesMV.CurrentAxes;
ImageRangeAll = getappdata(CurrentAxes, 'ImageRangeAll');
minFrame  = str2num(get(handlesMV.Min_Frame_edit, 'String'));
maxFrame  = str2num(get(handlesMV.Max_Frame_edit, 'String'));
currFrame = str2num(get(handlesMV.Frame_Value_edit, 'String'));
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

if minFrame < ImageRangeAll(1), minFrame = ImageRangeAll(1); end;
if minFrame > currFrame       , minFrame = currFrame; end;

if maxFrame > ImageRangeAll(2), maxFrame = ImageRangeAll(2); end;
if maxFrame < currFrame       , maxFrame = currFrame; end;

% specify single or all axes
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	setappdata(CurrentAxes(i), 'ImageRange', [minFrame maxFrame]);
	set(handlesMV.Min_Frame_edit, 'String', minFrame);
	set(handlesMV.Max_Frame_edit, 'String', maxFrame);
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Reset_Frame_Limit
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
CurrentAxes = handlesMV.CurrentAxes;
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

% specify single or all axes
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	ImageRangeAll = getappdata(CurrentAxes(i), 'ImageRangeAll');
	setappdata(CurrentAxes(i), 'ImageRange',ImageRangeAll );
	set(handlesMV.Min_Frame_edit, 'String', num2str(ImageRangeAll(1)) );
	set(handlesMV.Max_Frame_edit, 'String', num2str(ImageRangeAll(2)) );
end;

Set_Current_Axes(handlesMV.CurrentAxes);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Play_Movie
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

global GLOBAL_STOP_MOVIE

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
apply_all = get(handlesMV.Apply_radiobutton, 'Value');
frame_rate = str2num(get(handlesMV.Frame_Rate_edit, 'String'));

set([handlesMV.Reset_pushbutton, handlesMV.Min_Frame_edit, handlesMV.Max_Frame_edit, ...
		handlesMV.Frame_Value_edit, handlesMV.Rewind_pushbutton, handlesMV.Step_Rewind_pushbutton, ....
		handlesMV.Step_Forward_pushbutton, handlesMV.Forward_pushbutton, handlesMV.Play_pushbutton, ...
		handlesMV.Frame_Rate_edit, handlesMV.Make_Movie_pushbutton, ...
		handlesMV.Make_Mat_checkbox, handlesMV.Make_Avi_checkbox, handlesMV.Show_Frames_checkbox,...
        handlesMV.Show_Objects_checkbox, handlesMV.Object_List_popupmenu], 'Enable', 'off');
    %%%CHUS%%%Added objects to disable
		

% specify single or all axes
CurrentAxes = handlesMV.CurrentAxes;
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

for i = 1:length(CurrentAxes)
	current_frame{i} = getappdata(CurrentAxes(i), 'CurrentImage');
	image_range{i}   = getappdata(CurrentAxes(i), 'ImageRange');
	image_data{i}    = getappdata(CurrentAxes(i), 'ImageData');
   
    if ~isempty(handlesMV.ObjectHandles);
        object_data{i} = getappdata(CurrentAxes(i), 'Objects');
    end;    
end;

GLOBAL_STOP_MOVIE = 0;
t = 0;
while ~GLOBAL_STOP_MOVIE
	tic
	for i = 1:length(CurrentAxes)
		direction = 1;
		if     (current_frame{i} + direction) > image_range{i}(2), current_frame{i} = image_range{i}(1); 
		elseif (current_frame{i} + direction) < image_range{i}(1), current_frame{i} = image_range{i}(2); 
		else                                                       current_frame{i} = current_frame{i} + direction; end;		
		set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', image_data{i}(:,:,current_frame{i}));
		set(handlesMV.htFrameNumbers(find(handlesMV.Axes == CurrentAxes(i))), 'String', num2str(current_frame{i}));
        
        %%%CHUS%%%
        if ~isempty(handlesMV.ObjectHandles)
            % Objects Exist- update the xdata/ydata for each object for each axis
            for j = 1:size(handlesMV.ObjectHandles{i},1)
                Update_Object(object_data{i}, handlesMV.ObjectHandles{find(handlesMV.Axes==CurrentAxes(i))},current_frame{i});
            end;                            
        end;
        %%%CHUS%%%
        
	end;
	drawnow;
	pause(t);
	if 1/toc > frame_rate, t = t+0.01; end;	
end;

% exit - update values for each of the axes in movie to correspond to last
% frame played
if (GLOBAL_STOP_MOVIE ~= 2)
	for i = 1:length(CurrentAxes)
		setappdata( CurrentAxes(i), 'CurrentImage', current_frame{i});		
		set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', image_data{i}(:,:,current_frame{i}));
		drawnow;
		if (handlesMV.CurrentAxes==CurrentAxes(i))
			% if doing the single current axes 
			set(handlesMV.Frame_Value_edit, 'String', num2str(current_frame{i}));	
			Set_Current_Axes(CurrentAxes(i));
		end;
	end;
	
    % Turn objects back on
    set([handlesMV.Reset_pushbutton, handlesMV.Min_Frame_edit, handlesMV.Max_Frame_edit, ...
        handlesMV.Frame_Value_edit, handlesMV.Rewind_pushbutton, handlesMV.Step_Rewind_pushbutton, ....
        handlesMV.Step_Forward_pushbutton, handlesMV.Forward_pushbutton, handlesMV.Play_pushbutton, ...
        handlesMV.Frame_Rate_edit, handlesMV.Make_Movie_pushbutton, ...
        handlesMV.Make_Mat_checkbox, handlesMV.Make_Avi_checkbox, handlesMV.Show_Frames_checkbox], 'Enable', 'On');

    %%%CHUS%%%
    if ~isempty(handlesMV.ObjectHandles)
        set([handlesMV.Show_Objects_checkbox, handlesMV.Object_List_popupmenu], 'Enable', 'On');
    end;
    %%%CHUS%%%
    figure(fig2);
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Make_Movie
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
CurrentAxes = handlesMV.CurrentAxes;
handle_for_movie = CurrentAxes;
apply_all = get(handlesMV.Apply_radiobutton, 'Value');
make_avi  = get(handlesMV.Make_Avi_checkbox, 'Value');
make_mat  = get(handlesMV.Make_Mat_checkbox, 'Value');
frame_rate = str2num(get(handlesMV.Frame_Rate_edit, 'String'));
minFrame   = str2num(get(handlesMV.Min_Frame_edit, 'String'));
maxFrame   = str2num(get(handlesMV.Max_Frame_edit, 'String'));

if make_avi | make_mat
    if str2num(version('-release')) > 12.1        
        [filename, pathname] = uiputfile( {'*.m;*.avi', 'Movie Files (*.m, *.avi)'}, ...
            'Save Movie As', 'M');
    else
        [filename, pathname] = uiputfile( {'*.m;*.avi', 'Movie Files (*.m, *.avi)'}, ...
            'Save Movie As');
    end;

	if isequal(filename,0) | isequal(pathname,0)
		% User hit cancel instead of ok
		return;
	end;

    filename = [pathname, filename];
	
	
	% Turn objects off while movie is made
	set([handlesMV.Reset_pushbutton, handlesMV.Min_Frame_edit, handlesMV.Max_Frame_edit, ...
		handlesMV.Frame_Value_edit, handlesMV.Rewind_pushbutton, handlesMV.Step_Rewind_pushbutton, ....
		handlesMV.Step_Forward_pushbutton, handlesMV.Forward_pushbutton, handlesMV.Play_pushbutton, ...
		handlesMV.Frame_Rate_edit, handlesMV.Make_Movie_pushbutton, handlesMV.Stop_pushbutton, ...
		handlesMV.Make_Avi_checkbox, handlesMV.Make_Mat_checkbox, handlesMV.Show_Frames_checkbox, ...
        handlesMV.Show_Objects_checkbox, handlesMV.Object_List_popupmenu],...
	'Enable', 'Off');	
else
	% do nothing!
	return;
end;
	
% if apply_all, make movie of the whole figure moving together.
if apply_all 
	CurrentAxes = handlesMV.Axes;
	handle_for_movie = handlesMV.ParentFigure;
end;

% collect info for each of the frames to be used.
for i = 1:length(CurrentAxes)
	image_range{i}   = getappdata(CurrentAxes(i), 'ImageRange');
	image_data{i}    = getappdata(CurrentAxes(i), 'ImageData');
	current_frame{i} = image_range{i}(1);
	object_data{i}   = getappdata(CurrentAxes(i), 'Objects');
    
	if CurrentAxes(i)==handlesMV.CurrentAxes
		endFrame = image_range{i}(2); 
		iRef   = i;
	end;
end;

% play each frame; note that number of frames specified by the
% editable text boxes (ie the current axes frame limits) are used 
% to make movie - even if other windows have different number of 
% frames though each axes will start at their own beginning frame
stop_movie = 0;
counter = 1;
direction = 0;
while ~stop_movie
	for i = 1:length(CurrentAxes)
		if     (current_frame{i} + direction) > image_range{i}(2), current_frame{i} = image_range{i}(1); 
		elseif (current_frame{i} + direction) < image_range{i}(1), current_frame{i} = image_range{i}(2); 
		else                                                       current_frame{i} = current_frame{i} + direction; end;	
		set(findobj(CurrentAxes(i), 'Type', 'image'), 'CData', image_data{i}(:,:,current_frame{i}));
		set(handlesMV.htFrameNumbers(find(handlesMV.Axes == CurrentAxes(i))), 'String', num2str(current_frame{i}));
        
        %%%CHUS%%%
        if ~isempty(handlesMV.ObjectHandles)
            for j = 1:size(handlesMV.ObjectHandles{i},1)
                Update_Object(object_data{i}, handlesMV.ObjectHandles{find(handlesMV.Axes==CurrentAxes(i))},current_frame{i});
            end;
        end;
        %%%CHUS%%%
        
	end;
	drawnow;
	M(counter) = getframe(handle_for_movie);
	counter = counter + 1;
	direction = 1;
	% now determine if the movie is over: have played the last frame 
	% of the reference axes (current)
	if current_frame{iRef} == endFrame
		stop_movie = 1;
	end	
end;

if make_mat 
	f = [filename, '.mat'];
	save(f, 'M');
end;

compression = 'CinePak';
if isunix
	compression = 'None';
end;

Q = 75;
%%%CHUS%%%
%if isempty(handlesMV.ObjectHandles), Q = 100; compression = 'None'; end;
%%%CHUS%%%

compression

if make_avi
    f = filename;
    if isempty(strfind(f, '.avi')), f = [filename, '.avi']; end;
	try
		movie2avi(M, f, 'FPS', frame_rate, 'Compression', compression, 'Quality', Q);
	catch
		disp(['Error within movie2avi function call']);
		disp(['  Movie was not created.']);
	end;
end;	

% Turn objects back on
set([handlesMV.Reset_pushbutton, handlesMV.Min_Frame_edit, handlesMV.Max_Frame_edit, ...
		handlesMV.Frame_Value_edit, handlesMV.Rewind_pushbutton, handlesMV.Step_Rewind_pushbutton, ....
		handlesMV.Step_Forward_pushbutton, handlesMV.Forward_pushbutton, handlesMV.Play_pushbutton, ...
		handlesMV.Frame_Rate_edit, handlesMV.Make_Movie_pushbutton, handlesMV.Stop_pushbutton, ...
		handlesMV.Make_Avi_checkbox, handlesMV.Make_Mat_checkbox, handlesMV.Show_Frames_checkbox],...
	'Enable', 'On');


%%%CHUS%%%
if ~isempty(handlesMV.ObjectHandles)
    set([handlesMV.Show_Objects_checkbox, handlesMV.Object_List_popupmenu], 'Enable', 'On');
end; %%%CHUS%%%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Stop_Movie
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

global GLOBAL_STOP_MOVIE
GLOBAL_STOP_MOVIE = 1;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Show_Frames
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
visibility = get(handlesMV.Show_Frames_checkbox, 'Value');
if visibility, visibility = 'On' ;
else           visibility = 'Off'; end;
set(handlesMV.htFrameNumbers, 'visible', visibility);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Set_Current_Axes(currentaxes)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
aD = getAD;
if isempty(currentaxes), currentaxes=gca; end;
aD.hCurrentAxes = currentaxes;
image_range = getappdata(aD.hCurrentAxes, 'ImageRange');
aD.handlesMV.Min_Frame_edit.String =  num2str(image_range(1));
aD.handlesMV.Max_Frame_edit.String =  num2str(image_range(2));

% if ~isempty(aD.hObjects)
%     hCurrentAxes_idx = aD.Axes==aD.hCurrentAxes;
%     aD.handlesMV.Object_List_popupmenu.String = ...
%         aD.hObjects{hCurrentAxes_idx,3});
% end;

storeAD(aD);

%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Menu_MV(~,~)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
aD = getAD;
aD.hUtils.menuToggle(aD.hMenu,aD.hButton);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  Show_Objects
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function toggle the display of the objects
dispDebug;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);

if ~isempty(handlesMV.ObjectHandles)
    % Objects exist (they have already been drawn)
    show = get(handlesMV.Show_Objects_checkbox, 'value');

    % Make the checkbox work
    set(handlesMV.Show_Objects_checkbox, 'Enable', 'on');
    % make the PopupMenu (already filled) visible
    if show
        set(handlesMV.Object_List_popupmenu, 'Visible', 'on');
    else
        set(handlesMV.Object_List_popupmenu, 'Visible', 'off');
    end        
    for i = 1:size(handlesMV.ObjectHandles,1)
        h_obj= handlesMV.ObjectHandles{i};
        if show
            set(h_obj(h_obj~=0), 'Visible', 'on');
        else
            set(h_obj(h_obj~=0), 'Visible', 'off');
        end
    end;    
else

    % There are no objects
    set(handlesMV.Show_Objects_checkbox, 'Enable', 'off');
    set(handlesMV.Object_List_popupmenu, 'Visible', 'off');
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  Update_Object(ObjStruct, ObjectHandles, frame)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to update the relevant properties for each type of object
dispDebug;

for j = 1:size(ObjectHandles,1)
    switch ObjStruct(j).type
        case 'Line'
            set(ObjectHandles(j), ...
                'xdata', ObjStruct(j,frame).xdata(:), ...
                'ydata', ObjStruct(j,frame).ydata(:),...
                'Color', ObjStruct(j,frame).color);

        case 'Points'
            set(ObjectHandles(j), ...
                'xdata', ObjStruct(j,frame).xdata(:), ...
                'ydata', ObjStruct(j,frame).ydata(:),...
                'Color', ObjStruct(j,frame).color);

        case 'Patch'
            set(ObjectHandles(j), ...
                'xdata', ObjStruct(j,frame).xdata, ...
                'ydata', ObjStruct(j,frame).ydata,...
                'Facecolor', ObjStruct(j,frame).color, ...
                'FaceAlpha', ObjStruct(j,frame).facealpha ...
            );
    end
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  Toggle_Object(gcbo)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to toggle display of an object(s)
dispDebug;
popupmenu = gcbo;

fig2 = findobj('Tag', 'MV_figure');
handlesMV = guidata(fig2);
CurrentAxes = handlesMV.CurrentAxes;
ObjectHandles = handlesMV.ObjectHandles;
apply_all = get(handlesMV.Apply_radiobutton, 'Value');

toggle_val = get(popupmenu, 'Value');
popupmenu_string = get(popupmenu,'String');
toggle_string = popupmenu_string(toggle_val,:);

% specify single or all axes
if apply_all
	CurrentAxes = handlesMV.Axes;
end;

Hide = strmatch('Hide', toggle_string);
if isempty(Hide) , newstring = 'Hide'; oldstring = 'Show'; visibility = 'on';
else               newstring = 'Show'; oldstring = 'Hide'; visibility = 'off';
end;
    
for i = 1:length(CurrentAxes)
    currobjects = ObjectHandles{find(handlesMV.Axes==CurrentAxes(i)),1};
    popupmenu_string(toggle_val,:) = strrep(toggle_string,oldstring,newstring);
    for j = 1:size(currobjects,1)        
        if strmatch(deblank(get(currobjects(j),'Userdata')), deblank(toggle_string(6:end)))  
            set(currobjects(j), 'Visible', visibility);
            set(popupmenu, 'String', popupmenu_string);
        end;
    end;
    ObjectHandles{find(handlesMV.Axes==CurrentAxes(i)),3} = popupmenu_string;    
end;

handlesMV.ObjectHandles = ObjectHandles;
guidata(fig2, handlesMV);
%%%CHUS%%%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function Close_Parent_Figure(hFig,~)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to make sure that if parent figure is closed, 
% the ROI info and ROI Tool are closed too.
dispDebug;

global GLOBAL_STOP_MOVIE 
GLOBAL_STOP_MOVIE = 2;

aD = getAD;
if ~isempty(aD)
    hToolFig = aD.hToolFig;
else
    % Parent Figure is already closed and aD is gone
    dispDebug('ParFig closed!');
    objNames = retrieveNames;
    hToolFig = findobj(groot, 'Tag', objNames.figTag); 
end

hFigPZ.CloseRequestFcn = 'closereq';
try
    close(hFigPZ);
catch
    delete(hFigPZ);
end;

hFig.CloseRequestFcn = 'closereq';
close(hFig);
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

%call->MV_tool('Deactivate_MV');
aD.hButton.State = 'off';
aD.hRoot.ShowHiddenHandles= old_SHH;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%START SUPPORT FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  dispDebug(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Print a debug string if global debug flag is set
global DB;

if DB
    objectNames = retrieveNames;
    x = dbstack;
    func_name = x(2).name;    loc = [];
    if length(x) > 3
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

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function buttonImage = makeButtonImage
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The default button size is 15 x 16 x 3.
dispDebug;

buttonSize_x= 16;
buttonImage = NaN* zeros(15,buttonSize_x);

f= [...
    9    10    11    12    13    14    15    24    30    39    45    50    51    52    53    54    60, ...
    65    69    75    80    84    90    91    92    93    94    95    99   100   101   102   103   104, ...
    105   106   110   116   121   125   131   135   136   140   141   142   143   144   145   146   149, ...
    151   157   163   166   172   177   181   182   183   184   185   186   187   189   191   204   205, ...
    219   220   221 ...
    ];

buttonImage(f) = 0;
buttonImage = repmat(buttonImage, [1,1,3]);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function structNames = retrieveNames
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
structNames.toolName            = 'MV_tool';
structNames.buttonTag           = 'figViewImages';
structNames.buttonToolTipString = 'View Images & Make Movies';
structNames.menuTag             = 'menuViewImages';
structNames.menuLabel           = 'Movie Tool';
structNames.figFilename         = 'MV_tool_figure.fig';
structNames.figName             = 'MV Tool';
structNames.figTag              = 'MV_figure';
structNames.activeFigureName    = 'ActiveFigure';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  storeAD(aD)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
setappdata(aD.hFig, 'MVData', aD);
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
    hUtils = MR_Toolbox_Utilities;
    obj = hUtils.findHiddenObj('Tag', objNames.buttonTag);
    while ~strcmpi(obj.Type, 'Figure')
        obj = obj.Parent;
    end
    hFig = obj;
end

if isappdata(hFig, 'MVData')
    aD = getappdata(hFig, 'MVData');
end

dispDebug(['end (',num2str(toc),')']);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function hIm = findAxesChildIm(hAllAxes)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

hIm = gobjects(size(hAllAxes));
for i = 1:length(hAllAxes)
    hIm(i) = findobj(hAllAxes(i), 'Type', 'Image');
end    
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function hFrameNumbers = createFrameNumbers(hFig, hAllAxes, hIms)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Calc text size
textFontSize = 20;
figUnits = hFig.Units;
hFig.Units = 'inches';
figSize = hFig.Position;
reffigSize = 8;   % 8 inch figure gets 20 pt font
textFontSize = textFontSize * figSize(3) / reffigSize;
hFig.Units = figUnits;

% Create text object per axes
hFrameNumbers = gobjects(size(hAllAxes));
for i = 1:length(hAllAxes)
	X = hAllAxes(i).XLim;
	Y = hAllAxes(i).YLim;
    str = num2str(getappdata(hAllAxes(i), 'CurrentImage')); 
 	hFrameNumbers(i) = text(hAllAxes(i), X(2)*0.98, Y(2), str);
end;
[hIms(:).ButtonDownFcn] = deal('MV_tool(''Step'')');
[hFrameNumbers(:).FontSize] = deal(textFontSize);
[hFrameNumbers(:).Color] = deal([ 1 0.95 0]);
[hFrameNumbers(:).VerticalAlignment] = deal('bottom');
[hFrameNumbers(:).HorizontalAlignment] = deal('right');
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function [h_object, name_object] = drawObjects(aD)
% %%%CHUS%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to draw a series of pre-drawn objects per axis; 
%  Objects change with temporal dimension

%%%CHUS%%%
% draw temporal objects, if found
h_objects = {};
for i = 1:length(h_all_axes)
    if isappdata(h_all_axes(i), 'Objects')
        % Objects exist, Draw them
        % Might be a problem if the first axes doesn't have objects but
        % later ones do. FIX
        [h_objects{i,1}, h_objects{i,2}] = drawObject(getappdata(h_all_axes(i), 'Objects'),h_all_axes(i)) ;
        % load the current axes objets onto popupmenu
        if(h_all_axes(i)==h_axes)
            popupstring = [repmat('Hide ',size(h_objects{i,2},1),1),h_objects{i,2}]
            set(hGUI.Object_List_popupmenu, 'String', popupstring);
        end;
        h_objects{i,3} = popupstring;
    end;
end;
hGUI.ObjectHandles = h_objects;    
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function [h_object, name_object] = drawObject(ObjStruct, h_axes)
% %%%CHUS%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Function to cycle through drawing objects; 
%  Each object (data loaded inti appdata 'Objects' for each axes, is
%  composed of structure that contains field type (line,point,patch), 
%  xdata ydata and color 

dispDebug;

CurrImage = getappdata(h_axes,'CurrentImage'); 
fig = get(h_axes, 'Parent');

old_nextplot = get(h_axes, 'nextplot');
set(h_axes, 'Nextplot', 'add');

name_object = [];

for i = 1:size(ObjStruct,1)
   
    if strcmp(ObjStruct(i,CurrImage).type, 'Line')
        h_object(i,1) = plot(h_axes, ObjStruct(i,CurrImage).xdata(:), ObjStruct(i,CurrImage).ydata(:),...
            'color', ObjStruct(i,CurrImage).color );
        linestyle = '-';
        marker = 'none';
    elseif strcmp(ObjStruct(i,CurrImage).type, 'Points')
        h_object(i,1) = plot(h_axes, ObjStruct(i,CurrImage).xdata(:), ObjStruct(i,CurrImage).ydata(:),...
            'color', ObjStruct(i,CurrImage).color );
        linestyle = 'none';
        marker = ObjStruct(i,CurrImage).marker;
    
    elseif strcmp(ObjStruct(i,CurrImage).type, 'Patch')
        set(0, 'CurrentFigure', fig);
        set(fig, 'CurrentAxes', h_axes)
        h_object(i,1) = patch(ObjStruct(i,CurrImage).xdata(:), ObjStruct(i,CurrImage).ydata(:),...
            ObjStruct(i,CurrImage).color);
        linestyle = 'none';
        marker = 'none';
    else
        disp('Unknown object type!');
    end;

    name_object = strvcat(name_object, ObjStruct(i,CurrImage).name);
    
        % These apply to all objects (lines/points/patches)
    set(h_object(i,1),...
        'Marker', marker,...
        'linestyle', linestyle,...
        'Userdata', ObjStruct(i,CurrImage).name);

end
set(h_axes, 'Nextplot', old_nextplot);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
