package;

import flash.media.Sound;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class Paths
{
    public static var imageExt:String = 'png';
    public static var soundExt:String = #if html5 'mp3'; #else 'ogg'; #end

    // For caching images and sounds, which makes assets load faster
    public static var imageCache:Map<String, FlxGraphic> = [];
    public static var soundCache:Map<String, Sound> = [];

    // Textures and sounds (in case if the paths have multiple uses)
    public static var textures:Map<String, String> = [];
    public static var sounds:Map<String, String> = [
        "wing" => 'sfx_wing',
        "hit" => 'sfx_hit',
        "point" => 'sfx_point',
        "swooshing" => 'sfx_swooshing',
        "die" => 'sfx_die'
    ];
    public static var fonts:Map<String, String> = [
        "default" => '04B.TTF',
    ];

    // Paths
    public static function imagePath(key:String)
    {
        return 'assets/images/$key.$imageExt';
    }

    public static function soundPath(key:String, isMusic:Bool = false)
    {
        var folder:String = 'sounds';
        if (isMusic)
            folder = 'music';

        return 'assets/$folder/$key.$soundExt';
    }

    // Files
    public static function imageFile(key:String):FlxGraphic
    {
        var graphic:FlxGraphic = null;
        var path:String = imagePath(key);

        if (imageCache.exists(path))
        {
            graphic = imageCache.get(path);
        }
        else
        {
            #if sys
            var bitmap:BitmapData = BitmapData.fromFile(path);
            #else
            var bitmap:BitmapData = OpenFlAssets.getBitmapData(path);
            #end

            graphic = FlxGraphic.fromBitmapData(bitmap, false, path);
            graphic.persist = true;
            graphic.destroyOnNoUse = true;

            imageCache.set(path, graphic);
        }

        return graphic;
    }

    public static function soundFile(key:String, isMusic:Bool = false):Sound
    {
        var sound:Sound = null;
        var path:String = soundPath(key, isMusic);

        if (soundCache.exists(path))
        {
            sound = soundCache.get(path);
        }
        else
        {
            #if sys
            sound = Sound.fromFile(path);
            #else
            sound = OpenFlAssets.getSound(path);
            #end

            soundCache.set(path, sound);
        }

        return sound;
    }

    public static function fontFile(key:String)
    {
        return 'assets/fonts/$key';
    }

    public static function levelsFolder(levelFolder:String = 'default', ?levelName:String)
    {
        var additionalPath:String = '';

        if (levelName != null)
            additionalPath = '/$levelName';

        return 'assets/levels/${levelFolder}${additionalPath}';
    }

    public static function levelFile(levelFolder:String = 'default', levelName:String)
    {
        return '${levelsFolder(levelFolder, levelName)}/level.json';
    }

    public static function objectJson(objectName:String)
    {
        return 'assets/data/objects/$objectName.json';
    }

    public static function textFile(folder:String = 'data', key:String)
    {
        return 'assets/$folder/$key.txt';
    }

    public static function fileExists(path:String)
    {
        var exists:Bool = false;

        #if sys
        if (FileSystem.exists(path))
            exists = true;
        #else
        if (OpenFlAssets.exists(path, null))
            exists = true;
        #end

        return exists;
    }

    public static function getText(path:String)
    {
        var content:String = "";

        if (fileExists(path))
        {
            #if sys
            content = File.getContent(path);
            #else
            content = OpenFlAssets.getText(path);
            #end
        }

        return content;
    }

    public static function dumpCache()
    {
        for (key in imageCache.keys())
        {
            var graphic:FlxGraphic = imageCache.get(key);

            if (graphic != null)
            {
                imageCache.remove(key);

                OpenFlAssets.cache.removeBitmapData(key);

                graphic.persist = false;
                graphic.destroyOnNoUse = true;
                graphic.destroy();
            }
        }

        for (key in soundCache.keys())
        {
            var sound:Sound = soundCache.get(key);

            if (sound != null)
            {
                soundCache.remove(key);
                OpenFlAssets.cache.removeSound(key);
            }
        }
    }

    // Key value getting functions
    public static function getTexture(key:String):String
    {
        var value:String = '';
        
        if (textures.exists(key))
            value = textures.get(key);

        return value;
    }

    public static function getSound(key:String):String
    {
        var value:String = '';
        
        if (sounds.exists(key))
            value = sounds.get(key);

        return value;
    }

    public static function getFont(key:String):String
    {
        var value:String = '';
        
        if (fonts.exists(key))
            value = fonts.get(key);

        return value;
    }
}