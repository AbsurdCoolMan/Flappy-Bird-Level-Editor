package states;

import backend.FlappySettings;
import backend.FlappyState;
import backend.FlappyTools;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import haxe.Json;
import objects.Background;
import objects.ButtonGroup;
import objects.CameraObject;
import objects.Object;

using StringTools;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef LevelData = {
    levelName:String,
    scrollSpeed:Float,
    objects:Array<LevelObjectData>
}

typedef LevelObjectData = {
    name:String,
    x:Float,
    y:Float,
    scale:Float,
    flipped:Bool,
    variables:Array<Array<Dynamic>>
}

class EditorState extends FlappyState
{
    var bg:Background;
    var camFollow:CameraObject;
    var hudCamera:FlxCamera;

    var grpObjects:FlxTypedGroup<Object>;
    var grpLines:FlxTypedGroup<FlxSprite>;
    var tabMenu:FlxUITabMenu;

    // Other things
    var tabs:Array<{name:String, label:String}> = [
        {name: 'editor', label: 'Editor'},
        {name: 'level', label: 'Level'},
        {name: 'object', label: 'Object'}
    ];

    var inputTexts:Array<FlxUIInputText> = [];
    var numericSteppers:Array<FlxUINumericStepper> = [];
    var dropdowns:Array<FlxUIDropDownMenu> = [];

    var editObject:Object;
    var editCursor:FlxSprite;
    var instructionsTxt:FlxText;
    var grpButtons:ButtonGroup;

    var buttons:Array<String> = [
        'exit',
        'start'
    ];

    var buttonCallbacks:Array<Void->Void> = [
        function(){
            FlappyState.switchState(new MenuState());
        }
    ];

    var gridSize:Int = FlappySettings.editorGridSize;

    var selectedObject:Object = null;

    // Editor properties
    var levelData:LevelData = {
        levelName: 'example-level',
        scrollSpeed: 4,
        objects: []
    }

    var loadLevelName:String = '';
    var saveToDefault:Bool = false;

    var objectNames:Array<String> = [];

    override public function new(?levelData:LevelData)
    {
        super();

        if (levelData != null)
        {
            this.levelData = levelData;
        }
    }
    
    override function create()
    {
        PlayState.editorMode = true;

        hudCamera = new FlxCamera();
        hudCamera.bgColor.alpha = 0;
        FlxG.cameras.add(hudCamera, false);

        buttonCallbacks.push(function(){
            FlappySettings.levelJson = levelData;
            FlappyState.switchState(new PlayState());
        });

        var objectsPath:String = Paths.textFile('data', 'objectsList');
        if (Paths.fileExists(objectsPath))
        {
            var content:String = Paths.getText(objectsPath);
            var texts:Array<String> = content.split('\n');
            for (text in texts)
            {
                objectNames.push(text.trim());
            }
        }

        bg = new Background();
        add(bg);

        grpLines = new FlxTypedGroup<FlxSprite>();
        bg.backObjects.add(grpLines);

        grpObjects = new FlxTypedGroup<Object>();
		bg.backObjects.add(grpObjects);

        editCursor = new FlxSprite();
        editCursor.makeGraphic(1, 1, FlxColor.fromRGB(255, 255, 255, 0));
        add(editCursor);

        editObject = new Object(0, 0, 'pipe', true);
        editObject.alpha = 0.5;
        @:privateAccess
        editObject._lastAlpha = editObject.alpha;
        add(editObject);

        tabMenu = new FlxUITabMenu(null, tabs, true);
        tabMenu.resize(250, 250);
        tabMenu.setPosition(FlxG.width - tabMenu.width, FlxG.height - tabMenu.height);
        tabMenu.scrollFactor.set();
        add(tabMenu);

        instructionsTxt = new FlxText(0, 0, tabMenu.width + 32, '', 18);
        instructionsTxt.setFormat(Paths.fontFile(Paths.fonts.get('default')), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);

        instructionsTxt.text = 'Controls:'
        + '\nA/D or LeFt/Right to move'
        + '\nHold SHIFT to speed up moving'
        + '\nHold CTRL to slow down moving'
        + '\nScroll wheel to scroll'
        + '\nLeFt click to place object'
        + '\nRight click to delete object'
        + '\nCTRL + LeFt click to select object'
        + '\nT to toggle buttons'
        + '\nX to hide instructions';

        instructionsTxt.x = FlxG.width - instructionsTxt.width;
        instructionsTxt.y = tabMenu.y - instructionsTxt.height - 18;

        instructionsTxt.scrollFactor.set();
        add(instructionsTxt);

        grpButtons = new ButtonGroup(buttons, Horizontal, -1, buttonCallbacks);

        for (button in grpButtons.members)
        {
            button.y = button.height / 2.5;
            button.x -= button.width * 1.5;
        }

        add(grpButtons);

        addEditorTab();
        addLevelTab();
        addObjectTab();

        loadStuff();

        camFollow = new CameraObject();
        camFollow.screenCenter();
		camFollow.y -= 12;

        tabMenu.cameras = [hudCamera];
        instructionsTxt.cameras = [hudCamera];
        grpButtons.cameras = [hudCamera];

        super.create();
    }

    override function update(elapsed:Float)
    {
        // Positioning
        editCursor.x = FlxG.mouse.x;
        editCursor.y = FlxG.mouse.y;
        editObject.x = Math.floor(editCursor.x / gridSize) * gridSize;
        editObject.y = Math.floor(editCursor.y / gridSize) * gridSize;

        // Focus check
        var canDoStuff:Bool = true;

        for (input in inputTexts)
        {
            if (input.hasFocus)
            {
                canDoStuff = false;
                break;
            }
        }

        for (stepper in numericSteppers)
        {
            @:privateAccess
            var input:FlxUIInputText = cast stepper.text_field;

            if (input.hasFocus)
            {
                canDoStuff = false;
                break;
            }
        }

        for (dropdown in dropdowns)
        {
            if (dropdown.hasFocus)
            {
                canDoStuff = false;
                break;
            }
        }

        if (!canDoStuff)
        {  
            keys.toggleVolumeKeys(false);
        }
        else
        {
            keys.toggleVolumeKeys(true);
            
            // Move
            if (keys.LEFT || keys.RIGHT)
            {
                var posAdd:Int = keys.LEFT ? -1 : 1;
                var speed:Float = FlappySettings.editorScrollSpeed;
    
                if (FlxG.keys.pressed.SHIFT)
                    speed *= 1.5;
                else if (FlxG.keys.pressed.CONTROL)
                    speed /= 1.5;
    
                camFollow.x += posAdd * speed;
            }

            // Hide instructions
            if (FlxG.keys.justPressed.X && instructionsTxt.visible)
                instructionsTxt.visible = false;

            // Toggle buttons
            if (FlxG.keys.justPressed.T)
            {
                for (button in grpButtons.members)
                    button.visible = !button.visible;
                grpButtons.visible = grpButtons.members[0].visible;
            }
    
            // Scroll
            if (FlxG.mouse.wheel != 0)
            {
                camFollow.x += -(FlxG.mouse.wheel * FlappySettings.editorScrollSpeed * 2 * 10);
            }
    
            // Rotation
            if (keys.FLIP)
            {
                if (editObject.canBeFlipped)
                    editObject.flipped = !editObject.flipped;
            }

            // Keys
            var selectKey:Bool = (FlxG.mouse.justPressed && FlxG.keys.pressed.CONTROL);
            var addKey:Bool = FlxG.mouse.justPressed;
            var deleteKey:Bool = FlxG.mouse.justPressedRight;

            if ((selectKey || addKey || deleteKey) && !FlxG.mouse.overlaps(tabMenu, hudCamera)
                && (!FlxG.mouse.overlaps(grpButtons, hudCamera) || !grpButtons.visible))
            {
                if (deleteKey || selectKey)
                {
                    for (object in grpObjects.members)
                    {
                        if (FlxCollision.pixelPerfectCheck(editCursor, object, 0))
                        {
                            if (selectKey)
                                setObjectSelection(object);
                            else
                                removeObject(object.x, object.y, object.objectName);
                            break;
                        }
                    }
                }
                else
                    placeObject(editObject.x, editObject.y, editObject.objectName, editObject.scaleMulti, editObject.flipped);
            }
        }

        super.update(elapsed);

        if (camFollow.x < FlxG.width / 2)
            camFollow.x = FlxG.width / 2;

        MenuState.camPosX = camFollow.x;
    }

    // Object stuff
    function updateObjects()
    {
        while (grpObjects.length > 0)
        {
            grpObjects.remove(grpObjects.members[0], true);
        }

        for (item in levelData.objects)
        {
            var object:Object = new Object(item.x, item.y, item.name, true);
            object.scaleMulti = item.scale;
            object.flipped = item.flipped;
            object.variables = item.variables;
            grpObjects.add(object);
        }

        updateLines();
    }

    function updateLines()
    {
        while (grpLines.length > 0)
        {
            grpLines.remove(grpLines.members[0], true);
        }

        for (item in levelData.objects)
        {
            if (item.name == 'point' || item.name == 'end')
            {
                var line:FlxSprite = new FlxSprite(item.x, 0);
                line.makeGraphic(2, FlxG.height + 50, FlxColor.fromRGB(255, 255, 255, 135));
                line.screenCenter(Y);
                grpLines.add(line);
            }
        }
    }

    function placeObject(x:Float = 0, y:Float = 0, name:String, scale:Float, flipped:Bool)
    {
        var canPlace:Bool = true;

        for (item in levelData.objects)
        {
            if (item.x == x && item.y == y && item.name == name && item.scale == scale && item.flipped == flipped)
            {
                canPlace = false;
                break;
            }
        }

        if (canPlace)
        {
            if (selectedObject != null)
                setObjectSelection(selectedObject, false);

            var variables:Array<Array<Dynamic>> = [];

            if (Paths.fileExists(Paths.objectJson(name)))
            {
                var json:ObjectData = FlappyTools.loadJSON(Paths.objectJson(name));

                if (json.variables != null)
                    variables = json.variables;
            }

            levelData.objects.push({
                name: name,
                x: x,
                y: y,
                scale: scale,
                flipped: flipped,
                variables: variables
            });
        }

        updateObjects();
    }

    function removeObject(x:Float = 0, y:Float = 0, name:String)
    {
        for (item in levelData.objects)
        {
            if (item.x == x && item.y == y && item.name == name)
            {
                levelData.objects.remove(item);
                break;
            }
        }

        if (selectedObject != null)
            setObjectSelection(selectedObject, false);

        updateObjects();
        updateObjectTab();
    }

    function setObjectSelection(object:Object, select:Bool = true)
    {
        for (obj in grpObjects.members)
        {
            if (obj.selected)
            {
                obj.selected = false;
                break;
            }
        }  
        
        if (select && object != null)
        {
            object.selected = select;
            selectedObject = object;
            
            tabMenu.selected_tab = 2;
        }
        else
            selectedObject = null;

        updateObjectTab();
    }

    // Editor tabs
    private function addEditorTab()
    {
        var group:FlxUI = new FlxUI(null, tabMenu);
        group.name = 'editor';

        var saveButton:FlxButton = new FlxButton(15, 10, 'Save Level', function(){
            saveLevel();
        });

        var loadButton:FlxButton = new FlxButton(15, 35, 'Load Level', function(){
            loadLevel(loadLevelName);
        });
        
        var loadLevelNameInput:FlxUIInputText = new FlxUIInputText(102, 38, 100, loadLevelName);
        loadLevelNameInput.name = 'loadLevelInput';
        inputTexts.push(loadLevelNameInput);

        var loadLevelNameText:FlxText = new FlxText(109, 23, 0, 'Load Level Name');

        var clearButton:FlxButton = new FlxButton(15, 60, 'Clear Level', function(){
            clearLevel();
        });

        var objectNameItems = FlxUIDropDownMenu.makeStrIdLabelArray(objectNames);
        var objectNameDropdown:FlxUIDropDownMenu = new FlxUIDropDownMenu(15, 85, objectNameItems, function(objectName:String){
            editObject.objectName = objectName;
        });
        objectNameDropdown.selectedLabel = editObject.objectName;
        dropdowns.push(objectNameDropdown);

        var objectNameText:FlxText = new FlxText(140, 89, 0, 'Object Name');

        var saveToDefaultCheckbox:FlxUICheckBox = new FlxUICheckBox(15, 110, null, null, 'Save to Default (DEBUG)');
        saveToDefaultCheckbox.name = 'saveToDefaultCheckbox';
        saveToDefaultCheckbox.callback = function(){
            saveToDefault = saveToDefaultCheckbox.checked;
        }

        group.add(saveButton);
        group.add(loadButton);
        group.add(loadLevelNameInput);
        group.add(loadLevelNameText);
        group.add(clearButton);
        #if debug
        group.add(saveToDefaultCheckbox);
        #end
        group.add(objectNameDropdown);
        group.add(objectNameText);

        tabMenu.addGroup(group);
    }

    var levelNameInput:FlxUIInputText;
    var scrollSpeedStepper:FlxUINumericStepper;

    private function addLevelTab()
    {
        var group:FlxUI = new FlxUI(null, tabMenu);
        group.name = 'level';

        levelNameInput = new FlxUIInputText(15, 13, 100, levelData.levelName);
        levelNameInput.name = 'levelNameInput';
        inputTexts.push(levelNameInput);

        var levelNameText:FlxText = new FlxText(120, 14, 0, 'Level Name');

        scrollSpeedStepper = new FlxUINumericStepper(15, 35, 1, levelData.scrollSpeed, 1, 99);
        scrollSpeedStepper.name = 'scrollSpeedStepper';
        numericSteppers.push(scrollSpeedStepper);

        var scrollSpeedText:FlxText = new FlxText(77, 36, 0, 'Scroll Speed');

        group.add(levelNameInput);
        group.add(levelNameText);
        group.add(scrollSpeedStepper);
        group.add(scrollSpeedText);
        
        tabMenu.addGroup(group);
    }

    private function updateLevelTab()
    {
        levelNameInput.text = levelData.levelName;
        scrollSpeedStepper.value = levelData.scrollSpeed;
    }

    var objectPosXStepper:FlxUINumericStepper;
    var objectPosYStepper:FlxUINumericStepper;
    var objectNameDropdown:FlxUIDropDownMenu;
    var objectFlippedCheckbox:FlxUICheckBox;
    var objectScaleStepper:FlxUINumericStepper;
    var objectScaleText:FlxText;
    var objectVarDropdown:FlxUIDropDownMenu;
    var objectVarInput:FlxUIInputText;
    var objectVarText:FlxText;

    private function addObjectTab()
    {
        var group:FlxUI = new FlxUI(null, tabMenu);
        group.name = 'object';

        objectPosXStepper  = new FlxUINumericStepper(15, 10, 5, 0, 0, 999999);
        objectPosXStepper.name = 'objectPosXStepper';
        numericSteppers.push(objectPosXStepper);

        objectPosYStepper = new FlxUINumericStepper(15, 25, 5, 0, 0, 999999);
        objectPosYStepper.name = 'objectPosYStepper';
        numericSteppers.push(objectPosYStepper);

        var objectPosText:FlxText = new FlxText(77, 17.5, 0, 'Position X/Y');

        var objectNameItems = FlxUIDropDownMenu.makeStrIdLabelArray(objectNames);
        objectNameDropdown = new FlxUIDropDownMenu(15, 45, objectNameItems, function(objectName:String){
            if (selectedObject != null)
            {
                for (item in levelData.objects)
                {
                    if (item.x == selectedObject.x && item.y == selectedObject.y && item.name == selectedObject.objectName)
                    {
                        item.name = objectName;
                        selectedObject.objectName = objectName;

                        item.variables = [];

                        if (Paths.fileExists(Paths.objectJson(item.name)))
                        {
                            var json:ObjectData = FlappyTools.loadJSON(Paths.objectJson(item.name));
            
                            if (json.variables != null)
                                item.variables = json.variables;
                        }

                        selectedObject.variables = item.variables;

                        updateObjectTab();
                        updateLines();
                    }
                }
            }
        });
        objectNameDropdown.selectedLabel = '';
        dropdowns.push(objectNameDropdown);

        var objectNameText:FlxText = new FlxText(140, 49, 0, 'Object Name');

        objectFlippedCheckbox = new FlxUICheckBox(15, 70, null, null, 'Flipped?');
        objectFlippedCheckbox.callback = function(){
            if (selectedObject != null)
            {
                for (item in levelData.objects)
                {
                    if (item.x == selectedObject.x && item.y == selectedObject.y && item.name == selectedObject.objectName)
                    {
                        item.flipped = objectFlippedCheckbox.checked;
                        selectedObject.flipped = objectFlippedCheckbox.checked;
                        updateObjectTab();
                        updateLines();
                    }
                }
            }
        }

        objectScaleStepper = new FlxUINumericStepper(15, 95, 0.1, 1, 0.1, 10, 2);
        objectScaleStepper.name = 'objectScaleStepper';
        numericSteppers.push(objectScaleStepper);

        objectScaleText = new FlxText(77, 95, 0, 'Scale');

        objectVarText = new FlxText(22, 120, 0, 'Variables');

        var objectVarItems = FlxUIDropDownMenu.makeStrIdLabelArray(['no']);
        objectVarDropdown = new FlxUIDropDownMenu(15, 135, objectVarItems, function(variable:String){
            if (objectVarInput != null && selectedObject != null)
            {
                for (varr in selectedObject.variables)
                {
                    if (varr[0] == variable)
                    {
                        objectVarInput.text = Std.string(varr[1]);
                    }
                }
            }
        });

        objectVarDropdown.selectedLabel = 'no';
        dropdowns.push(objectVarDropdown);

        objectVarInput = new FlxUIInputText(140, 138, 50, '');
        objectVarInput.name = 'objectVarInput';
        inputTexts.push(objectVarInput);

        group.add(objectPosXStepper);
        group.add(objectPosYStepper);
        group.add(objectPosText);
        group.add(objectFlippedCheckbox);
        group.add(objectScaleStepper);
        group.add(objectScaleText);
        group.add(objectVarText);
        group.add(objectVarDropdown);
        group.add(objectVarInput);
        group.add(objectNameDropdown);
        group.add(objectNameText);
        
        tabMenu.addGroup(group);
    }

    private function updateObjectTab()
    {
        objectFlippedCheckbox.active = false;
        objectFlippedCheckbox.visible = false;

        objectScaleStepper.active = false;
        objectScaleStepper.visible = false;

        objectScaleText.active = false;
        objectScaleText.visible = false;

        objectVarDropdown.active = false;
        objectVarDropdown.visible = false;

        objectVarInput.active = false;
        objectVarInput.visible = false;

        objectVarText.active = false;
        objectVarText.visible = false;

        if (selectedObject != null)
        {
            objectPosXStepper.value = selectedObject.x;
            objectPosYStepper.value = selectedObject.y;
            objectNameDropdown.selectedLabel = selectedObject.objectName;
            objectFlippedCheckbox.checked = selectedObject.flipped;
            objectScaleStepper.value = selectedObject.scaleMulti;

            if (selectedObject.canBeFlipped)
            {
                objectFlippedCheckbox.active = true;
                objectFlippedCheckbox.visible = true;
            }

            if (selectedObject.canBeScaled)
            {
                objectScaleStepper.active = true;
                objectScaleStepper.visible = true;

                objectScaleText.active = true;
                objectScaleText.visible = true;
            }

            if (selectedObject.variables.length > 0)
            {
                objectVarDropdown.active = true;
                objectVarDropdown.visible = true;

                objectVarInput.active = true;
                objectVarInput.visible = true;

                objectVarText.active = true;
                objectVarText.visible = true;

                var items:Array<String> = [];
                var values:Array<Dynamic> = [];

                for (variable in selectedObject.variables)
                {
                    items.push(variable[0]);
                    values.push(variable[1]);
                }

                var objectVarItems = FlxUIDropDownMenu.makeStrIdLabelArray(items);
                objectVarDropdown.setData(objectVarItems);
                objectVarDropdown.selectedLabel = items[0];

                objectVarInput.text = values[0];
            }
        }
    }

    override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
    {
        if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
        {
            var input:FlxUIInputText = cast sender;
            var name:String = input.name;

            switch (name)
            {
                case 'loadLevelInput':
                    loadLevelName = input.text;
                case 'levelNameInput':
                    levelData.levelName = input.text;
                case 'objectVarInput':
                    if (selectedObject != null && objectVarDropdown != null)
                    {
                        for (item in levelData.objects)
                        {
                            if (item.x == selectedObject.x && item.y == selectedObject.y && item.name == selectedObject.objectName)
                            {
                                for (i in 0...item.variables.length)
                                {
                                    if (item.variables[i][0] == objectVarDropdown.selectedLabel)
                                    {
                                        item.variables[i][1] = input.text;
                                        selectedObject.variables[i][1] = input.text;
                                    }
                                }
                            }
                        }
                    }
            }
        }
        else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
        {
            var stepper:FlxUINumericStepper = cast sender;
            var name:String = stepper.name;

            switch (name)
            {
                case 'scrollSpeedStepper':
                    levelData.scrollSpeed = stepper.value;
                case 'objectPosXStepper' | 'objectPosYStepper':
                    if (selectedObject != null)
                    {
                        for (item in levelData.objects)
                        {
                            if (item.x == selectedObject.x && item.y == selectedObject.y && item.name == selectedObject.objectName)
                            {
                                if (name == 'objectPosXStepper')
                                {
                                    item.x = stepper.value;
                                    selectedObject.x = item.x;
                                }
                                else
                                {
                                    item.y = stepper.value;
                                    selectedObject.y = item.y;
                                }

                                updateLines();
                            }
                        }
                    }
                case 'objectScaleStepper':
                    if (selectedObject != null)
                    {
                        for (item in levelData.objects)
                        {
                            if (item.x == selectedObject.x && item.y == selectedObject.y && item.name == selectedObject.objectName)
                            {
                                item.scale = stepper.value;
                                selectedObject.scaleMulti = item.scale;
                            }
                        }
                    }
            }
        }
        else if (id == FlxUITabMenu.CLICK_EVENT && (sender is FlxUITabMenu))
        {
            var tabMenu:FlxUITabMenu = cast sender;
            var curTab:Int = tabMenu.selected_tab;

            switch (curTab)
            {
                case 2:
                    updateObjectTab();
            }
        }
    }

    override function destroy()
    {
        super.destroy();

        FlxG.cameras.remove(hudCamera, true);
        FlxG.camera.zoom = 1;
    }

    // Save and load stuff
    private function saveLevel()
    {
        var jsonString:String = Json.stringify(levelData, '\t');

        var path:String = 'custom';
        if (saveToDefault)
            path = 'default';

        #if sys
        if (!Paths.fileExists(Paths.levelsFolder(path, levelData.levelName)))
            FileSystem.createDirectory(Paths.levelsFolder(path, levelData.levelName));

        File.saveContent(Paths.levelFile(path, levelData.levelName), jsonString);
        #end
    }

    private function loadLevel(levelName:String)
    {
        var newJsonLoaded:Bool = false;

        #if sys
        var json:LevelData = FlappyTools.loadJSON(Paths.levelFile('custom', levelName));
        if (json != null)
        {
            levelData = json;
            newJsonLoaded = true;
        }

        var json:LevelData = FlappyTools.loadJSON(Paths.levelFile('default', levelName));
        if (json != null)
        {
            levelData = json;
            newJsonLoaded = true;
        }
        #end

        if (newJsonLoaded)
        {
            loadStuff();
        }
    }

    function loadStuff()
    {
        setObjectSelection(selectedObject, false);
        updateObjects();
        updateLevelTab();
    }

    private function clearLevel()
    {
        levelData.objects = [];
        updateObjects();
    }
}