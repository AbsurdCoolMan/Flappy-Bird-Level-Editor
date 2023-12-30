package backend;

import flixel.FlxG;
import flixel.addons.display.FlxExtendedMouseSprite;
import flixel.util.FlxColor;

class FlappyButton extends FlxExtendedMouseSprite
{
    public var buttonName:String = '';
    public var clickSound:Bool = false;

    private var justClicked:Bool = false;
    private var justReleased:Bool = false;
    private var justHovered:Bool = false;
    private var justHoverEnded:Bool = false;

    // Callbacks
    public var onClicked:Void->Void;
    public var onReleased:Void->Void;
    public var onHover:Void->Void;
    public var onHoverEnd:Void->Void;

    // Brightnesses
    public var hoverBrightness:Float = 0.9;
    public var clickBrightness:Float = 0.6;

    override public function new(x:Float = 0, y:Float = 0, buttonName:String = '')
    {
        super(x, y);

        this.buttonName = buttonName;

        loadGraphic(Paths.imageFile('buttons/$buttonName'));
        
        scale.set(3, 3);
        updateHitbox();

        scrollFactor.set();
    }

    override function update(elapsed:Float)
    {
        if (mouseOver)
            hover();
        else
            hoverEnd();

        if (isPressed)
            clicked();
        else
            released();

        super.update(elapsed);
    }

    private function clicked()
    {
        justReleased = false;
        setBrightness(clickBrightness);
        
        if (justClicked) return;

        if (clickSound)
            FlxG.sound.play(Paths.soundFile(Paths.sounds.get('swooshing'), false));

        if (onClicked != null)
            onClicked();

        justClicked = true;
    }

    private function released()
    {
        justClicked = false;
        if (justReleased) return;

        if (onReleased != null)
            onReleased();

        justReleased = true;
    }

    private function hover()
    {
        justHoverEnded = false;
        setBrightness(hoverBrightness);

        if (justHovered) return;

        if (onHover != null)
            onHover();

        justHovered = true;
    }

    public function hoverEnd()
    {
        justHovered = false;
        setBrightness(1);

        if (justHoverEnded) return;

        if (onHoverEnd != null)
            onHoverEnd();

        justHoverEnded = true;
    }

    public function setBrightness(brightness:Float)
    {
        color = FlxColor.fromHSB(color.hue, color.saturation, brightness);
    }
}