package states;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;

class MainMenuState extends UCNState
{
    override public function create():Void
    {
        super.create();

        var text = new FlxText(0, 0, FlxG.width, "MainMenuState placeholder");
        text.setFormat(null, 24, 0xffffffff, FlxTextAlign.CENTER);
        text.screenCenter();
        add(text);
    }
}
