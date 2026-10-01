package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;
import openfl.Assets;
import openfl.media.Sound;
import openfl.utils.AssetType;

/**
 * Intro state based on the Clickteam intro events.
 *
 * The visual/audio assets are intentionally placeholders so the state can be
 * wired to the real dump later without changing the timing logic.
 */
class IntroState extends UCNState
{
    static inline final BOOM_TIME:Float = 6.0;
    static inline final WHISPER_TIME:Float = 0.10;
    static inline final GLITCH_INTERVAL:Float = 0.25;
    static inline final JUMP_FALLBACK_SOUND_TIME:Float = 1.0;
    static inline final JUMP_SHAKE_POWER:Int = 10;
    static inline final FADE_STEP:Int = 10;
    static inline final MAX_ALPHA_VALUE:Int = 255;
    static inline final BOOM_SOUND_ID:String = "assets/sounds/boom2.ogg";
    static inline final WHISPER_SOUND_ID:String = "assets/sounds/whisper4.ogg";
    static inline final PLEASE_IMAGE_ID:String = "assets/images/title/please.png";
    static inline final PLEASE_ATLAS_ID:String = "assets/images/title/please.xml";
    static inline final ENTER_IMAGE_ID:String = "assets/images/title/enter.png";
    static inline final ENTER_ATLAS_ID:String = "assets/images/title/enter.xml";
    static inline final ROCK_FREDDY_ID:String = "assets/images/title/rock_freddy.png";
    static inline final WARNING_IMAGE_ID:String = "assets/images/title/warning.png";
    static inline final JUMP_1_ID:String = "assets/images/title/jumps_1.png";
    static inline final JUMP_2_ID:String = "assets/images/title/jumps_2.png";

    var cnLogo:FlxSprite;
    var enterPrompt:FlxSprite;
    var rockFreddy:FlxSprite;
    var warning:FlxSprite;
    var jumpScare:FlxSprite;
    var fadeOverlay:FlxSprite;

    var fadeValue:Int = 0;
    var fadeMode:IntroFadeMode = Waiting;
    var canSkip:Bool = false;
    var didJump:Bool = false;
    var glitchTimer:Float = 0;
    var jumpTimer:Float = 0;
    var jumpFrame:Int = 0;
    var jumpDuration:Float = JUMP_FALLBACK_SOUND_TIME;
    var jumpSwitchTime:Float = JUMP_FALLBACK_SOUND_TIME * 0.5;
    var jumpBaseX:Float = 0;
    var jumpBaseY:Float = 0;

    var boomSound:FlxSound;
    var whisperSound:FlxSound;

    override public function create():Void
    {
        super.create();
        FlxG.camera.bgColor = 0xff000000;

        setupSave();

        #if official
        if (getAdjustValue() == 1)
        {
            goToNextState();
            return;
        }
        #end

        setupCnLogo();
        setupTitleExtras();
        setupFadeOverlay();
        registerIntroEditorObjects();
        setupAudio();
        setupTimeline();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (didJump)
            return;

        updateJumpScare(elapsed);
        updateFade();
        updateSkipInput();
    }

    function setupCnLogo():Void
    {
        cnLogo = new FlxSprite();

        if (Assets.exists(PLEASE_IMAGE_ID, AssetType.IMAGE) && Assets.exists(PLEASE_ATLAS_ID, AssetType.TEXT))
        {
            cnLogo.frames = FlxAtlasFrames.fromSparrow(PLEASE_IMAGE_ID, PLEASE_ATLAS_ID);
            cnLogo.animation.addByPrefix("idle", "pls", 24, true);
        }
        else
        {
            trace("Missing intro atlas: " + PLEASE_IMAGE_ID + " / " + PLEASE_ATLAS_ID);
            cnLogo.makeGraphic(350, 77, 0xffffffff);
        }

        cnLogo.scale.set(1, 1);
        cnLogo.updateHitbox();
        cnLogo.screenCenter();
        cnLogo.animation.play("idle");

        add(cnLogo);
    }

    function setupTitleExtras():Void
    {
        setupRockFreddy();
        setupWarning();
        setupEnterPrompt();
        setupJumpScare();
    }

    function setupRockFreddy():Void
    {
        rockFreddy = new FlxSprite();

        if (Assets.exists(ROCK_FREDDY_ID, AssetType.IMAGE))
            rockFreddy.loadGraphic(ROCK_FREDDY_ID);
        else
            rockFreddy.makeGraphic(240, 240, 0xffff0000);

        rockFreddy.scale.set(1, 1);
        rockFreddy.updateHitbox();
        rockFreddy.x = 434 - rockFreddy.width;
        rockFreddy.y = 1272 - rockFreddy.height;
        rockFreddy.visible = false;
        add(rockFreddy);
    }

    function setupWarning():Void
    {
        warning = new FlxSprite();

        if (Assets.exists(WARNING_IMAGE_ID, AssetType.IMAGE))
            warning.loadGraphic(WARNING_IMAGE_ID);
        else
            warning.makeGraphic(360, 90, 0xffffff00);

        warning.scale.set(1, 1);
        warning.updateHitbox();
        warning.screenCenter();
        warning.visible = false;
        add(warning);
    }

    function setupEnterPrompt():Void
    {
        enterPrompt = new FlxSprite();

        if (Assets.exists(ENTER_IMAGE_ID, AssetType.IMAGE) && Assets.exists(ENTER_ATLAS_ID, AssetType.TEXT))
        {
            enterPrompt.frames = FlxAtlasFrames.fromSparrow(ENTER_IMAGE_ID, ENTER_ATLAS_ID);
            enterPrompt.animation.addByPrefix("idle", "enter", 24, true);
            enterPrompt.animation.play("idle");
        }
        else
        {
            trace("Missing enter atlas: " + ENTER_IMAGE_ID + " / " + ENTER_ATLAS_ID);
            enterPrompt.makeGraphic(500, 110, 0xffffffff);
        }

        enterPrompt.updateHitbox();
        enterPrompt.screenCenter(X);
        enterPrompt.y = warning.y + 100;
        enterPrompt.visible = false;
        add(enterPrompt);
    }

    function setupJumpScare():Void
    {
        jumpScare = new FlxSprite();
        loadJumpFrame(0);
        coverScreen(jumpScare);
        jumpBaseX = jumpScare.x;
        jumpBaseY = jumpScare.y;
        jumpScare.visible = false;
        add(jumpScare);
    }

    function setupSave():Void
    {
        // Equivalent to setting the INI current file/group to "CN".
        FlxG.save.bind("CN");
    }

    function setupFadeOverlay():Void
    {
        fadeOverlay = new FlxSprite();
        fadeOverlay.makeGraphic(FlxG.width, FlxG.height, 0xff000000);
        fadeOverlay.alpha = 0;
        add(fadeOverlay);
    }

    function setupAudio():Void
    {
        boomSound = loadSound(BOOM_SOUND_ID);
        whisperSound = loadSound(WHISPER_SOUND_ID);
    }

    function registerIntroEditorObjects():Void
    {
        registerStageSprite("cnLogo", cnLogo);
        registerStageSprite("rockFreddy", rockFreddy);
        registerStageSprite("warning", warning);
        registerStageSprite("enterPrompt", enterPrompt);
        registerStageSprite("jumpScare", jumpScare);
        registerStageImage(PLEASE_IMAGE_ID);
        registerStageImage(ENTER_IMAGE_ID);
        registerStageImage(ROCK_FREDDY_ID);
        registerStageImage(WARNING_IMAGE_ID);
        registerStageImage(JUMP_1_ID);
        registerStageImage(JUMP_2_ID);
    }

    function setupTimeline():Void
    {
        new FlxTimer().start(WHISPER_TIME, function(_):Void
        {
            playSound(whisperSound, 0.10);
        });

        new FlxTimer().start(BOOM_TIME, function(_):Void
        {
            playSound(boomSound, 1.0);
            showJumpScare();

            new FlxTimer().start(jumpDuration, function(_):Void
            {
                jumpScare.visible = false;
                showTitleScreen();
                stopIntroAudio();
                fadeValue = 0;
                syncFadeOverlay();
                fadeMode = FadingIn;
            });
        });
    }

    function showJumpScare():Void
    {
        jumpScare.visible = true;
        cnLogo.visible = false;

        jumpTimer = 0;
        jumpFrame = 0;
        jumpDuration = getBoomDuration();
        jumpSwitchTime = jumpDuration * 0.5;
        loadJumpFrame(jumpFrame);
        coverScreen(jumpScare);
        jumpBaseX = jumpScare.x;
        jumpBaseY = jumpScare.y;
    }

    function showTitleScreen():Void
    {
        enterPrompt.visible = true;
        rockFreddy.visible = true;
        warning.visible = true;
    }

    function hideTitleSprites():Void
    {
        cnLogo.visible = false;
        enterPrompt.visible = false;
        rockFreddy.visible = false;
        warning.visible = false;
        jumpScare.visible = false;
    }

    function updateJumpScare(elapsed:Float):Void
    {
        if (!jumpScare.visible || fadeMode != Waiting)
            return;

        jumpTimer += elapsed;

        if (jumpTimer >= jumpDuration)
        {
            jumpScare.visible = false;
            jumpScare.x = jumpBaseX;
            jumpScare.y = jumpBaseY;
            return;
        }

        if (jumpFrame == 0 && jumpTimer >= jumpSwitchTime)
        {
            jumpFrame = 1;
            loadJumpFrame(jumpFrame);
            coverScreen(jumpScare);
            jumpBaseX = jumpScare.x;
            jumpBaseY = jumpScare.y;
        }

        jumpScare.x = jumpBaseX + FlxG.random.int(-JUMP_SHAKE_POWER, JUMP_SHAKE_POWER);
        jumpScare.y = jumpBaseY + FlxG.random.int(-JUMP_SHAKE_POWER, JUMP_SHAKE_POWER);
    }

    function getBoomDuration():Float
    {
        if (boomSound != null && boomSound.length > 0)
            return boomSound.length / 1000;

        return JUMP_FALLBACK_SOUND_TIME;
    }

    function loadJumpFrame(frame:Int):Void
    {
        var id:String = frame == 0 ? JUMP_1_ID : JUMP_2_ID;

        if (Assets.exists(id, AssetType.IMAGE))
            jumpScare.loadGraphic(id);
        else
            jumpScare.makeGraphic(FlxG.width, FlxG.height, 0xffffffff);
    }

    function coverScreen(sprite:FlxSprite):Void
    {
        var scale:Float = Math.max(FlxG.width / sprite.frameWidth, FlxG.height / sprite.frameHeight);
        sprite.scale.set(scale, scale);
        sprite.updateHitbox();
        sprite.screenCenter();
    }

    function updateFade():Void
    {
        switch (fadeMode)
        {
            case Waiting:

            case FadingIn:
                fadeValue += FADE_STEP;

                if (fadeValue > MAX_ALPHA_VALUE)
                {
                    fadeValue = MAX_ALPHA_VALUE;
                    fadeMode = WaitForEnter;
                    canSkip = true;
                }

                syncFadeOverlay();

            case WaitForEnter:

            case FadingOut:
                goToNextState();
        }
    }

    function updateSkipInput():Void
    {
        if (!canSkip || fadeMode != WaitForEnter)
            return;

        if (FlxG.keys.justPressed.ENTER)
        {
            fadeMode = FadingOut;
            canSkip = false;
            // Equivalent to setting INI item "adjust" value 1.
            FlxG.save.data.adjust = 1;
            FlxG.save.flush();
        }
    }

    function syncFadeOverlay():Void
    {
        fadeOverlay.alpha = 1 - Math.max(0, Math.min(1, fadeValue / MAX_ALPHA_VALUE));
    }

    function playSound(sound:FlxSound, volume:Float):Void
    {
        if (sound == null)
            return;

        sound.volume = volume;
        sound.play(true);
    }

    function stopIntroAudio():Void
    {
        if (boomSound != null)
            boomSound.stop();

        if (whisperSound != null)
            whisperSound.stop();
    }

    function getAdjustValue():Int
    {
        var value:Dynamic = FlxG.save.data.adjust;
        return Std.isOfType(value, Int) ? value : 0;
    }

    function loadSound(id:String):FlxSound
    {
        if (!Assets.exists(id, AssetType.SOUND))
        {
            trace('Missing intro sound: ' + id);
            return null;
        }

        var sound:Sound = Assets.getSound(id);
        return FlxG.sound.load(sound, 1.0, false);
    }

    function goToNextState():Void
    {
        didJump = true;
        stopIntroAudio();

        // Replace MainMenuState with the actual Frame 1 / menu state later.
        switchStateWithFade(new MainMenuState());
    }
}

enum IntroFadeMode
{
    Waiting;
    FadingIn;
    WaitForEnter;
    FadingOut;
}
