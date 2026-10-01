import flixel.FlxGame;
import openfl.display.Sprite;
import states.IntroState;

class Main extends Sprite
{
	public function new()
	{
		super();

		addChild(new FlxGame(1920, 1080, IntroState, 60, 60, false, true));
	}
}
