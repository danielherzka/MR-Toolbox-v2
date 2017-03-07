function utilFcn = MR_Toolbox_Utilities

% Create cell-list of available functions
fs={...
    'defaultButtonTags';...
    'retrieveNames';...
    'enableToolbarButtons';...
    'disableToolbarButtons';...
    'retrieveOrigData'; ...
    'restoreOrigData';...
    'findHiddenObj';...
    'createButtonObject';...
    'createMenuObject';...
    'menuToggle';...
    };

% Convert each name into a function handle reachable from outside this file 
for i=1:length(fs),
	utilFcn.(fs{i}) = str2func(fs{i});
end;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%START MULTI-TOOL SUPPORT FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function tags = defaultButtonTags %#ok<*DEFNU>>
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
utilDispDebug;

tags = { ...
    'figWindowLevel',...
    'figPanZoom',...
    'figROITool',...
    'figViewImages',...
    'figPointTool',...
    'figRotateTool',...
    'figProfileTool'};
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function structNames = retrieveNames
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
structNames.toolName            = '<Utils>';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function [hToolbar_Children, origToolEnables, origToolStates ] = disableToolbarButtons(hToolbar, currentToolName) 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
utilDispDebug;
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
%
function enableToolbarButtons(hToolbar_Children, origToolEnables, origToolStates)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
utilDispDebug;

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
function propList = retrieveOrigData(hObjs,propList)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrive previous settings for storage
utilDispDebug;

if nargin==1
    % basic list - typically modified figure properties
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
end

propList = repmat(propList, [1 1 length(hObjs)]);

for j = 1:length(hObjs) % objects
    for i = 1:size(propList,1) % properties
        if isprop(hObjs(j), propList{i,1,j})
            propList{i,2,j} = hObjs(j).(propList{i,1,j});
        end
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function restoreOrigData(hFig, propList)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Restore previous WBDF etc to restore state after WL is done.
utilDispDebug;
for j = 1:length(hFig)
    for i = 1:size(propList,1)
        hFig(j).(propList{i,1,j}) = propList{i,2,j};
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function h = findHiddenObj(Handle, Property, Value)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
utilDispDebug;

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
function  [hButton, hToolbar] = createButtonObject(...
    hFig, ...
    buttonImage, ...
    callbackOn, ...
    callbackOff,...
    buttonTag, ...
    buttonToolTipString)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
hToolbar = findall(hFig, 'type', 'uitoolbar', 'Tag','FigureToolBar' );

% If the toolbar exists and the button has not been previously created
if ~isempty(hToolbar) && isempty(findobj(hToolbar, 'Tag', buttonTag))
    
    hToolbar_Children = hToolbar.Children;
    buttonTags = defaultButtonTags();
    hButtons = cell(1,size(buttonTags,2));
    
    for i = 1:length(buttonTags)
        hButtons{i} = findobj(hToolbar_Children, 'Tag', buttonTags{i});
    end;
    
    separator = 'off';
    if isempty(hButtons)
        separator = 'on';
    end;
    
    hButton = uitoggletool(hToolbar);
    hButton.CData         = buttonImage;
    hButton.OnCallback    = callbackOn;
    hButton.OffCallback   = callbackOff;
    hButton.Tag           = buttonTag;
    hButton.TooltipString = buttonToolTipString;
    hButton.Separator     = separator;
    hButton.UserData      = hFig;
    hButton.Enable         = 'on';
else
    % Toolbar doesn't exist, or button already exists
    hButton = [];  
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  hMenu = createMenuObject(hFig, menuTag,menuLabel,callback)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
hToolMenu = findall(hFig, 'Label', '&Tools');

if ~isempty(hToolMenu) && isempty(findobj(hToolMenu,'Tag', menuTag))

    % If the menubar exists and the menu item has not been previously created
    hExistingMenus = findobj(hToolMenu, '-regexp', 'Tag', 'menu\w*');
    
    position = 9;
    separator = 'On';
    
    if ~isempty(hExistingMenus)
        position = position + length(hExistingMenus);
        separator = 'Off';
    end;
    
    hMenu = uimenu(hToolMenu,'Position', position);
    hMenu.Tag       = menuTag;
    hMenu.Label     = menuLabel;
    hMenu.Callback  = callback;
    hMenu.Separator = separator;
    hMenu.UserData  = hFig;
else
    hMenu = [];
end

%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function menuToggle(hMenu, hButton)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
utilDispDebug;

checked   = hMenu.Checked;
if strcmpi(checked,'on')
    % turn off button -> Deactivate_PZ
    hMenu.Checked = 'off';
    hButton.State = 'off';
else %hButton
    hMenu.Checked = 'on';
    hButton.State = 'on';
end;
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%START LOCAL SUPPORT FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  utilDispDebug(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Print a debug string if global debug flag is set
global DB;

if DB
    objectNames = retrieveNames;
    x = dbstack;
    funcName = x(2).name;    loc = [];
    callFuncName = x(3).file(1:end-2);
    if length(x) > 5
        loc = ['(loc)', repmat('|> ',1, length(x)-5)] ;
    end
    fprintf([callFuncName,' ',objectNames.toolName, ':', loc , ' %s'], funcName);
%     if nargin>0
%         for i = 1:length(varargin)
%             str = varargin{i};
%             fprintf(': %s', str);
%         end
%     end
    fprintf('\n');
    
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

