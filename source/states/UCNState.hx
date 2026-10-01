package states;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;
import openfl.system.System;
import openfl.utils.AssetType;

class UCNState extends FlxState
{
    static inline final DEFAULT_TRANSITION_TIME:Float = 0.35;
    static inline final EDITOR_TOGGLE_KEY:String = "F2";
    static inline final STAGE_WIDTH:Int = 1920;
    static inline final STAGE_HEIGHT:Int = 1080;
    static inline final SNAP_DISTANCE:Float = 12;

    var stageEditorEnabled:Bool = false;
    var stageEditorSnapEnabled:Bool = true;
    var stageEditorClampEnabled:Bool = false;
    var stageEditorEntries:Array<StageEditorEntry> = [];
    var stageEditorImages:Array<String> = [];
    var stageEditorSelected:Int = -1;
    var stageEditorImageIndex:Int = 0;
    var stageEditorDragging:Bool = false;
    var stageEditorDragOffsetX:Float = 0;
    var stageEditorDragOffsetY:Float = 0;
    var stageEditorHud:FlxText;
    var stageEditorMarker:FlxSprite;
    var stageEditorCenterDot:FlxSprite;

    override public function create():Void
    {
        super.create();
        fadeIn();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        updateStageEditor();
    }

    function registerStageSprite(name:String, sprite:FlxSprite):Void
    {
        if (sprite == null)
            return;

        stageEditorEntries.push({name: name, sprite: sprite, temporary: false});

        if (stageEditorSelected < 0)
            stageEditorSelected = 0;
    }

    function registerStageImage(id:String):Void
    {
        if (id != null && id.length > 0 && Assets.exists(id, AssetType.IMAGE))
            stageEditorImages.push(id);
    }

    function fadeIn(?duration:Float):Void
    {
        FlxG.camera.fade(FlxColor.BLACK, duration == null ? DEFAULT_TRANSITION_TIME : duration, true);
    }

    function switchStateWithFade(nextState:FlxState, ?duration:Float):Void
    {
        FlxG.camera.fade(FlxColor.BLACK, duration == null ? DEFAULT_TRANSITION_TIME : duration, false, function():Void
        {
            FlxG.switchState(nextState);
        });
    }

    function updateStageEditor():Void
    {
        if (FlxG.keys.anyJustPressed([EDITOR_TOGGLE_KEY]))
        {
            stageEditorEnabled = !stageEditorEnabled;

            if (stageEditorHud == null)
            {
                stageEditorHud = new FlxText(8, 8, 980, "");
                stageEditorHud.setFormat(null, 16, FlxColor.WHITE);
                stageEditorHud.scrollFactor.set();
                add(stageEditorHud);
            }

            if (stageEditorMarker == null)
            {
                stageEditorMarker = new FlxSprite();
                stageEditorMarker.makeGraphic(1, 1, FlxColor.TRANSPARENT);
                add(stageEditorMarker);
            }

            if (stageEditorCenterDot == null)
            {
                stageEditorCenterDot = new FlxSprite(STAGE_WIDTH * 0.5 - 4, STAGE_HEIGHT * 0.5 - 4);
                stageEditorCenterDot.makeGraphic(8, 8, 0xffff3333);
                stageEditorCenterDot.scrollFactor.set();
                add(stageEditorCenterDot);
            }

            stageEditorHud.visible = stageEditorEnabled;
            stageEditorMarker.visible = stageEditorEnabled;
            stageEditorCenterDot.visible = stageEditorEnabled;
        }

        if (!stageEditorEnabled)
            return;

        if (stageEditorEntries.length == 0)
        {
            stageEditorHud.text = "STAGE EDITOR (F2): no hay objetos registrados";
            return;
        }

        if (FlxG.keys.justPressed.TAB)
            stageEditorSelected = (stageEditorSelected + 1) % stageEditorEntries.length;
        if (FlxG.keys.justPressed.S)
            stageEditorSnapEnabled = !stageEditorSnapEnabled;
        if (FlxG.keys.justPressed.B)
            stageEditorClampEnabled = !stageEditorClampEnabled;

        if (FlxG.keys.justPressed.N && stageEditorImages.length > 0)
        {
            var id:String = stageEditorImages[stageEditorImageIndex % stageEditorImages.length];
            stageEditorImageIndex++;

            var sprite = new FlxSprite(FlxG.width * 0.5, FlxG.height * 0.5);
            sprite.loadGraphic(id);
            sprite.updateHitbox();
            sprite.screenCenter();
            add(sprite);
            stageEditorEntries.push({name: "temp:" + id, sprite: sprite, temporary: true});
            stageEditorSelected = stageEditorEntries.length - 1;
        }

        var entry = stageEditorEntries[stageEditorSelected];
        var selected = entry.sprite;
        var step:Float = FlxG.keys.pressed.SHIFT ? 10 : 1;

        if (FlxG.keys.pressed.LEFT)
            selected.x -= step;
        if (FlxG.keys.pressed.RIGHT)
            selected.x += step;
        if (FlxG.keys.pressed.UP)
            selected.y -= step;
        if (FlxG.keys.pressed.DOWN)
            selected.y += step;
        if (FlxG.keys.justPressed.Q)
            selected.scale.set(selected.scale.x - 0.05, selected.scale.y - 0.05);
        if (FlxG.keys.justPressed.E)
            selected.scale.set(selected.scale.x + 0.05, selected.scale.y + 0.05);
        if (FlxG.keys.justPressed.V)
            selected.visible = !selected.visible;
        if (FlxG.keys.justPressed.R)
            selected.angle = 0;
        if (FlxG.keys.justPressed.H)
        {
            selected.x = (STAGE_WIDTH - selected.width) * 0.5;
            selected.y = (STAGE_HEIGHT - selected.height) * 0.5;
        }
        if (FlxG.keys.justPressed.DELETE && entry.temporary)
        {
            remove(selected, true);
            stageEditorEntries.remove(entry);
            stageEditorSelected = Std.int(Math.max(0, stageEditorSelected - 1));
        }

        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(selected))
        {
            stageEditorDragging = true;
            stageEditorDragOffsetX = FlxG.mouse.x - selected.x;
            stageEditorDragOffsetY = FlxG.mouse.y - selected.y;
        }
        if (FlxG.mouse.justReleased)
            stageEditorDragging = false;
        if (stageEditorDragging)
        {
            selected.x = FlxG.mouse.x - stageEditorDragOffsetX;
            selected.y = FlxG.mouse.y - stageEditorDragOffsetY;
        }

        selected.updateHitbox();
        if (stageEditorSnapEnabled)
        {
            var centerX = selected.x + selected.width * 0.5;
            var centerY = selected.y + selected.height * 0.5;

            if (Math.abs(selected.x) <= SNAP_DISTANCE)
                selected.x = 0;
            if (Math.abs(selected.y) <= SNAP_DISTANCE)
                selected.y = 0;
            if (Math.abs((selected.x + selected.width) - STAGE_WIDTH) <= SNAP_DISTANCE)
                selected.x = STAGE_WIDTH - selected.width;
            if (Math.abs((selected.y + selected.height) - STAGE_HEIGHT) <= SNAP_DISTANCE)
                selected.y = STAGE_HEIGHT - selected.height;
            if (Math.abs(centerX - STAGE_WIDTH * 0.5) <= SNAP_DISTANCE)
                selected.x = (STAGE_WIDTH - selected.width) * 0.5;
            if (Math.abs(centerY - STAGE_HEIGHT * 0.5) <= SNAP_DISTANCE)
                selected.y = (STAGE_HEIGHT - selected.height) * 0.5;
        }

        if (stageEditorClampEnabled)
        {
            selected.x = Math.max(0, Math.min(STAGE_WIDTH - selected.width, selected.x));
            selected.y = Math.max(0, Math.min(STAGE_HEIGHT - selected.height, selected.y));
        }

        stageEditorMarker.makeGraphic(Std.int(Math.max(1, selected.width)), Std.int(Math.max(1, selected.height)), 0x33ffff00);
        stageEditorMarker.x = selected.x;
        stageEditorMarker.y = selected.y;

        var line = entry.name + ".x = " + Std.int(selected.x) + "; " + entry.name + ".y = " + Std.int(selected.y)
            + "; scale = " + selected.scale.x + "; center = " + Std.int(selected.x + selected.width * 0.5) + ", "
            + Std.int(selected.y + selected.height * 0.5) + "; size = " + Std.int(selected.width) + "x" + Std.int(selected.height);

        if (FlxG.keys.justPressed.C)
        {
            System.setClipboard(line);
            trace(line);
        }

        stageEditorHud.text = "STAGE EDITOR F2 | TAB objeto | flechas/mouse mover | SHIFT rapido | S snap "
            + (stageEditorSnapEnabled ? "ON" : "OFF") + " | B clamp " + (stageEditorClampEnabled ? "ON" : "OFF")
            + " | H centro | Q/E escala | V visible | N imagen | DEL temp | C copiar\n"
            + (stageEditorSelected + 1) + "/" + stageEditorEntries.length + " " + line;
    }
}

typedef StageEditorEntry =
{
    var name:String;
    var sprite:FlxSprite;
    var temporary:Bool;
}
