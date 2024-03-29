package;

import backend.FlappyData;
import backend.FlappySettings;
import backend.FlappyText;
import flixel.FlxG;
import flixel.FlxState;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.Http;
import lime.app.Application;
import states.IntroState;
import states.OutdatedState;

using StringTools;

class Init extends FlxState
{
    var loadedFiles:Int = 0;
    var totalFiles:Int = 0;
    var percentageBar:FlxBar;

    private var percent:Float = 0;

    var images:Array<String> = [];
    var sounds:Array<Dynamic> = [];
    
    public static var curVersion:String = '';
    public static var latestVersion:String = '';
    public static var showOutdated:Bool = false;
    public static var messages:Array<String> = [];

    override function create()
    {
        FlxG.mouse.useSystemCursor = true;

        FlappyData.init();
        FlappyData.load();

        // Version
        curVersion = 'v${Application.current.meta.get('version')}';

        var verHttp:Http = new Http(FlappySettings.verCheckLink);
        verHttp.onData = function(data:String){
            latestVersion = 'v${data.split('\n')[0].trim()}';

            if (curVersion != latestVersion)
                showOutdated = true;
        }
        verHttp.onError = function(error){
            trace('Error getting version ($error)!');
        }
        verHttp.request();

        // Message
        var messageHttp:Http = new Http(FlappySettings.messageLink);
        messageHttp.onData = function(data:String){
            for (msg in data.trim().split('\n'))
            {
                messages.push(msg.trim());
            }
        }
        messageHttp.onError = function(error){
            trace('Error getting message ($error)!');
        }
        messageHttp.request();

        var text:FlappyText = new FlappyText(0, 0, 0, 'Loading...', 32, CENTER);
        text.screenCenter();
        add(text);

        percentageBar = new FlxBar(0, text.y + 50, LEFT_TO_RIGHT, FlxG.width - 200, 10, this, "percent", 0, 1);
        percentageBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
        percentageBar.screenCenter(X);
        add(percentageBar);

        startCaching();

        super.create();
    }

    function startCaching()
    {
        Paths.dumpCache();

        // BG
        addImage('background/Sky');
        addImage('background/Ground');

        // Player skins
        addImage('playerSkins/default');
        addImage('playerSkins/blue');
        addImage('playerSkins/green');

        // Buttons
        addImage('buttons/start');
        addImage('buttons/editor');
        addImage('buttons/options');
        addImage('buttons/exit');
        addImage('buttons/resume');
        addImage('buttons/restart');
        addImage('buttons/menu');
        addImage('buttons/pause');

        // Objects
        addImage('objects/pipe');
        addImage('objects/point');
        addImage('objects/end');

        // Other
        addImage('title');
        addImage('getReady');
        addImage('gameover');
        addImage('gameComplete');
        addImage('uiBox');
        addImage('arrow');

        // Sounds
        addSound(Paths.getSound('wing'), false);
        addSound(Paths.getSound('hit'), false);
        addSound(Paths.getSound('point'), false);
        addSound(Paths.getSound('swooshing'), false);
        addSound(Paths.getSound('die'), false);

        for (image in images)
        {
            Paths.imageFile(image);

            var path:String = Paths.imagePath(image);
            var loaded:Bool = false;

            while (!loaded)
            {
                if (Paths.imageCache.exists(path))
                {
                    loaded = true;
                    loadedFiles++;
                }
            }
        }

        for (sound in sounds)
        {
            Paths.soundFile(sound[0], sound[1]);

            var path:String = Paths.soundPath(sound[0], sound[1]);
            var loaded:Bool = false;

            while (!loaded)
            {
                if (Paths.soundCache.exists(path))
                {
                    loaded = true;
                    loadedFiles++;
                }
            }
        }
    }

    function addImage(key:String)
    {
        totalFiles++;
        images.push(key);
    }

    function addSound(key:String, isMusic:Bool = false)
    {
        totalFiles++;
        sounds.push([key, isMusic]);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        percent = loadedFiles / totalFiles;

        if (percent >= 1)
        {
            boot();
        }
    }

    function boot()
    {
        if (showOutdated)
        {
            showOutdated = false;
            FlxG.switchState(new OutdatedState());
        }
        else
            FlxG.switchState(new IntroState());
    }
}