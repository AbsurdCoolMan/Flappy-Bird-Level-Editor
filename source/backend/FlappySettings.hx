package backend;

class FlappySettings
{
    // Main game settings
    public static var scrollSpeed:Float = 4;
    public static var menuScrollSpeed:Float = 2;
    public static var playerSkin:String = 'default';

    // Editor settings
    public static var editorScrollSpeed:Float = 8;
    public static var editorGridSize:Int = 16;

    // Links (NOTE TO SELF. UPDATE THESE ON RELEASE)
    public static var httpPrefix:String = 'https://raw.githubusercontent.com/AbsurdCoolMan/Flappy-Bird-Level-Editor-Public-Stuff/main/';
    public static var verCheckLink:String = '${httpPrefix}version.txt';
    public static var messageLink:String = '${httpPrefix}message.txt';
    public static var githubLink:String = 'https://github.com/AbsurdCoolMan/Flappy-Bird-Level-Editor';
}