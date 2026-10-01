package states;

import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class Frame1State extends UCNState
{
    public static inline final UI:String = "assets/images/frame1/ui/";
    public static inline final CHARS:String = "assets/images/frame1/animatronics/";
    public static inline final OGG:String = "assets/sounds/";

    static inline final CARD_W:Int = 150;
    static inline final CARD_H:Int = 200;
    static inline final GRID_X:Int = 40;
    static inline final GRID_Y:Int = 30;
    static inline final GAP_X:Int = 10;
    static inline final GAP_Y:Int = 5;
    static inline final PANEL_X:Int = 1660;

    var cards:Array<CharacterCard> = [];
    var ai:Array<Int> = [];
    var gridA:FlxSprite;
    var gridB:FlxSprite;
    var gridTime:Float = 0;
    var pointText:FlxText;
    var highText:FlxText;
    var infoBox:FlxSpriteGroup;
    var infoText:FlxText;
    var popup:FlxSpriteGroup;
    var showInfo:Bool = true;
    var visualEffects:Bool = true;
    var highScore:Int = 0;
    var openedPopup:Frame1Popup = None;
    var ambiance:FlxSound;

    override public function create():Void
    {
        super.create();

        ambiance = FlxG.sound.load(OGG + "Eisoptrophobia.ogg", 0.5, true);
        ambiance.play();


        FlxG.camera.bgColor = 0xff000000;

        ai = [for (_ in 0...CHARACTERS.length) 0];

        buildBackground();
        buildCards();
        buildRightPanel();
        buildInfoBox();
        popup = new FlxSpriteGroup(PANEL_X - 306, 0);
        popup.visible = false;
        add(popup);
        refreshScore();
    }

    override public function update(elapsed:Float):Void
    {
        gridTime += elapsed;
        gridA.x = -90 + Math.sin(gridTime * 0.55) * 20;
        gridB.x = 1120 + Math.sin(gridTime * 0.45) * 18;
        super.update(elapsed);
    }

    function buildBackground():Void
    {
        gridA = new FlxSprite(-90, -72);
        gridA.loadGraphic(UI + "bg-grid.png");
        gridA.scale.set(5.6, 2.05);
        gridA.angle = -7;
        gridA.alpha = 0.55;
        gridA.updateHitbox();
        add(gridA);

        gridB = new FlxSprite(1120, -82);
        gridB.loadGraphic(UI + "bg-grid.png");
        gridB.scale.set(5.2, 2.05);
        gridB.angle = 7;
        gridB.alpha = 0.42;
        gridB.updateHitbox();
        add(gridB);
    }

    function buildCards():Void
    {
        for (i in 0...CHARACTERS.length)
        {
            var col = i % 10;
            var row = Std.int(i / 10);
            var card = new CharacterCard(GRID_X + col * (CARD_W + GAP_X), GRID_Y + row * (CARD_H + GAP_Y), i, CHARACTERS[i], this);
            cards.push(card);
            add(card);
            registerStageSprite("card_" + CHARACTERS[i].id, card);
        }
    }

    function buildRightPanel():Void
    {
        add(new TextButton(PANEL_X + 25, 32, 200, 64, "SET ALL\n0", function() setAll(0)));
        add(new TextButton(PANEL_X + 25, 107, 200, 64, "ADD ALL\n1", addAllOne));
        add(new TextButton(PANEL_X + 25, 182, 200, 64, "SET ALL\n5", function() setAll(5)));
        add(new TextButton(PANEL_X + 25, 257, 200, 64, "SET ALL\n10", function() setAll(10)));
        add(new TextButton(PANEL_X + 25, 332, 200, 64, "SET ALL\n20", function() setAll(20)));

        add(new ImageButton(PANEL_X, 418, UI + "office.png", function() openPopup(Offices)));
        add(new ImageButton(PANEL_X, 468, UI + "power-ups.png", function() openPopup(PowerUps)));
        add(new ImageButton(PANEL_X, 518, UI + "challenges.png", function() openPopup(Challenges)));

        addImage(UI + "point-val.png", PANEL_X + 64, 575);
        pointText = text(PANEL_X + 120, 608, 180, "0", 62, FlxTextAlign.RIGHT);
        add(pointText);

        addImage(UI + "highscore.png", PANEL_X + 66, 670);
        highText = text(PANEL_X + 120, 705, 180, "0", 58, FlxTextAlign.RIGHT);
        add(highText);

        var best = text(PANEL_X + 55, 762, 230, "50/20 BEST TIME:\n0:00.0", 18, FlxTextAlign.RIGHT);
        add(best);

        add(new ToggleBox(PANEL_X + 38, 820, "Show\nChar Info", showInfo, function(v) showInfo = v));
        add(new ToggleBox(PANEL_X + 160, 820, "Visual\nEffects", visualEffects, function(v) visualEffects = v));
        addImage(UI + "erase-tip.png", PANEL_X + 42, 876);
        add(new ImageButton(PANEL_X, 896, UI + "go.png", function() trace("GO pending. Score=" + calculateScore())));
    }

    function buildInfoBox():Void
    {
        infoBox = new FlxSpriteGroup();
        infoBox.visible = false;
        add(infoBox);

        var bg = new FlxSprite();
        bg.loadGraphic(UI + "info-box.png");
        infoBox.add(bg);

        infoText = text(8, 6, 300, "", 17, FlxTextAlign.LEFT);
        infoBox.add(infoText);
    }

    function setAll(value:Int):Void
    {
        for (i in 0...ai.length)
            ai[i] = value;
        refreshCards();
    }

    function addAllOne():Void
    {
        for (i in 0...ai.length)
            ai[i] = Std.int(Math.min(20, ai[i] + 1));
        refreshCards();
    }

    function refreshCards():Void
    {
        for (card in cards)
            card.setAI(ai[card.index]);
        refreshScore();
    }

    function refreshScore():Void
    {
        pointText.text = Std.string(calculateScore());
        highText.text = Std.string(highScore);
    }

    function calculateScore():Int
    {
        var result = 0;
        for (value in ai)
            result += value * 10;
        return result;
    }

    public function changeAI(index:Int, delta:Int):Void
    {
        ai[index] = Std.int(Math.max(0, Math.min(20, ai[index] + delta)));
        cards[index].setAI(ai[index]);
        refreshScore();
    }

    public function showCharacterInfo(card:CharacterCard):Void
    {
        if (!showInfo || popup.visible)
        {
            infoBox.visible = false;
            return;
        }

        infoBox.visible = true;
        infoBox.x = Math.min(PANEL_X - 330, card.x + CARD_W + 10);
        infoBox.y = Math.max(0, card.y + 8);
        infoText.text = card.data.name + ": " + card.data.description;
    }

    function openPopup(next:Frame1Popup):Void
    {
        openedPopup = openedPopup == next ? None : next;
        popup.clear();
        popup.visible = openedPopup != None;

        switch (openedPopup)
        {
            case None:

            case Offices:
                popup.add(panelBg());
                var assets = ["default.png", "fnaf-5.png", "fnaf-3.png", "fnaf-4.png"];
                var locks = [0, 2000, 5000, 8000];
                for (i in 0...assets.length)
                {
                    var office = new FlxSprite(45, 24 + i * 230);
                    office.loadGraphic(UI + assets[i]);
                    office.alpha = highScore >= locks[i] ? 1 : 0.35;
                    popup.add(office);

                    if (highScore < locks[i])
                    {
                        var req = new FlxSprite(98, 92 + i * 230);
                        req.loadGraphic(UI + "require-" + locks[i] + ".png");
                        popup.add(req);
                    }
                }
                popup.add(new TextButton(35, 984, 250, 55, "OK", function() openPopup(None)));

            case PowerUps:
                popup.add(panelBg());
                var powers = ["power-frigid.png", "power-coins.png", "power-batery.png", "power-dd-repel.png"];
                for (i in 0...powers.length)
                {
                    var p = new FlxSprite(39, 40 + i * 235);
                    p.loadGraphic(UI + powers[i]);
                    popup.add(p);
                    popup.add(text(220, 48 + i * 235, 40, Std.string(5 - i), 38, FlxTextAlign.RIGHT));
                }
                popup.add(new TextButton(35, 984, 250, 55, "OK", function() openPopup(None)));

            case Challenges:
                var bg = new FlxSprite(16, 25);
                bg.makeGraphic(275, 1030, 0xee00152d);
                popup.add(bg);
                var names = ["Bears Attack 1", "Bears Attack 2", "Bears Attack 3", "Pay Attention 1", "Pay Attention 2", "Ladies Night 1", "Ladies Night 2", "Ladies Night 3", "Creepy Crawlies 1", "Creepy Crawlies 2", "Nightmares Attack", "Springtrapped", "Old Friends", "Chaos 1", "Chaos 2", "Chaos 3"];
                for (i in 0...names.length)
                    popup.add(new TextButton(32, 40 + i * 55, 250, 48, names[i], function() {}));
                popup.add(new ImageButton(32, 915, UI + "challenge-go.png", function() trace("Challenge GO pending")));
                popup.add(new ImageButton(32, 980, UI + "challenge-cancel.png", function() openPopup(None)));
        }
    }

    function panelBg():FlxSprite
    {
        var bg = new FlxSprite(8, 8);
        bg.loadGraphic(UI + "box-right.png");
        bg.scale.set(1.08, 1.02);
        bg.updateHitbox();
        return bg;
    }

    function addImage(asset:String, x:Float, y:Float):FlxSprite
    {
        var sprite = new FlxSprite(x, y);
        sprite.loadGraphic(asset);
        add(sprite);
        return sprite;
    }

    function text(x:Float, y:Float, width:Float, value:String, size:Int, align:FlxTextAlign):FlxText
    {
        var t = new FlxText(x, y, width, value);
        t.setFormat(null, size, FlxColor.WHITE, align);
        return t;
    }

    static final CHARACTERS:Array<CharacterData> = [
        c("Freddy Fazbear", "freddy", "freddy.png", "He approaches from the left hall. Track him on the monitor and close the door when he reaches the doorway."),
        c("Bonnie", "bonnie", "bonnie.png", "He blocks your view and punishes sloppy monitoring."),
        c("Chica", "chica", "chica.png", "Listen for kitchen activity and react before she reaches your office."),
        c("Foxy", "foxy", "foxy.png", "Check Pirate Cove and keep him from sprinting down the hall."),
        c("Toy Freddy", "toyFreddy", "toy-freddy.png", "Help him survive his own game."),
        c("Toy Bonnie", "toyBonnie", "toy-bonnie.png", "He slips through the right vent."),
        c("Toy Chica", "toyChica", "toy-chica.png", "She approaches through the front vent."),
        c("Mangle", "mangle", "mangle.png", "She crawls through the vent system."),
        c("BB", "bb", "ballon-boy.png", "He can disable tools if he gets into the office."),
        c("JJ", "jj", "jay-jay.png", "She disables door controls after entering."),
        c("Withered Chica", "witheredChica", "withered-chica.png", "She gets stuck in the vent opening."),
        c("Withered Bonnie", "witheredBonnie", "withered-bonnie.png", "Put on the mask when he appears."),
        c("Marionette", "marionette", "puppet.png", "Keep the music box wound."),
        c("Golden Freddy", "goldenFreddy", "golden-freddy.png", "Lower the monitor or use the mask when he appears."),
        c("Springtrap", "springtrap", "springtrap.png", "Seal him out of the vent system."),
        c("Phantom Mangle", "phantomMangle", "phantom-mangle.png", "Appears on the monitor and causes audio trouble."),
        c("Phantom Freddy", "phantomFreddy", "phantom-freddy.png", "Shine him away before he enters."),
        c("Phantom BB", "phantomBb", "phantom-bb.png", "Change cameras quickly when he appears."),
        c("Nightmare Freddy", "nightmareFreddy", "nightm-freddy.png", "Watch the Freddles and shine them away."),
        c("Nightmare Bonnie", "nightmareBonnie", "nigthm-bonnie.png", "Buy his plush before he attacks."),
        c("Nightmare Fredbear", "nightmareFredbear", "nightm-freddbear.png", "Listen for his door attack."),
        c("Nightmare", "nightmare", "nightmare.png", "A faster, darker door threat."),
        c("Jack-O-Chica", "jackOChica", "jack-o-chica.png", "Keep the office cool."),
        c("Nightmare Mangle", "nightmareMangle", "nightm-mangle.png", "Buy the plush to keep her away."),
        c("Nightmarionne", "nightmarionne", "nightm-puppet.png", "Do not leave the cursor on him."),
        c("Nightmare BB", "nightmareBb", "nightm-bb.png", "Use the flashlight when he sits up."),
        c("Old Man Consequences", "oldMan", "old-man.png", "Catch the fish when prompted."),
        c("Circus Baby", "circusBaby", "circus-baby.png", "Buy her plush before she attacks."),
        c("Ballora", "ballora", "ballora.png", "Listen for her hall approach."),
        c("Funtime Foxy", "funtimeFoxy", "funtime-foxy.png", "Check showtime on the stage."),
        c("Ennard", "ennard", "ennard.png", "He moves through the ducts."),
        c("Trash and the Gang", "trashGang", "trash-gang.png", "Mostly harmless distractions."),
        c("Helpy", "helpy", "helpy.png", "Click him quickly when he appears."),
        c("Happy Frog", "happyFrog", "happy-frog.png", "She moves through ducts."),
        c("Mr. Hippo", "mrHippo", "mr-hippo.png", "He moves through ducts."),
        c("Pigpatch", "pigpatch", "pigpatch.png", "He moves through ducts."),
        c("Nedd Bear", "neddBear", "nedd-bear.png", "He is less predictable in the ducts."),
        c("Orville Elephant", "orville", "orville-ele.png", "He is harder to lure away."),
        c("Rockstar Freddy", "rockstarFreddy", "rock-freddy.png", "Pay him Faz-Coins when he asks."),
        c("Rockstar Bonnie", "rockstarBonnie", "rock-bonnie.png", "Find his guitar on the cameras."),
        c("Rockstar Chica", "rockstarChica", "rock-chica.png", "Use wet floor signs to block her."),
        c("Rockstar Foxy", "rockstarFoxy", "rock-foxy.png", "His bird may help or betray you."),
        c("Music Man", "musicMan", "music-man.png", "Keep the noise level low."),
        c("El Chip", "elChip", "el-chip.png", "Close his ad when it appears."),
        c("Funtime Chica", "funtimeChica", "funtime-chica.png", "She causes visual distractions."),
        c("Molten Freddy", "moltenFreddy", "moltew-freddy.png", "Listen for his laugh in the vent."),
        c("Scrap Baby", "scrapBaby", "scrapbaby.png", "Shock her when she prepares to attack."),
        c("Afton", "afton", "scraptrap.png", "He attacks once. React fast."),
        c("Lefty", "lefty", "lefty.png", "Noise and heat make him aggressive."),
        c("Phone Guy", "phoneGuy", "phone-guy.png", "Mute his call before it wastes time.")
    ];

    static function c(name:String, id:String, image:String, description:String):CharacterData
    {
        return {name: name, id: id, image: CHARS + image, description: description};
    }
}

class CharacterCard extends FlxSpriteGroup
{
    public var index(default, null):Int;
    public var data(default, null):CharacterData;

    var owner:Frame1State;
    var portrait:FlxSprite;
    var border:FlxSprite;
    var valueText:FlxText;

    public function new(x:Float, y:Float, index:Int, data:CharacterData, owner:Frame1State)
    {
        super(x, y);
        this.index = index;
        this.data = data;
        this.owner = owner;

        portrait = new FlxSprite();
        portrait.loadGraphic(data.image);
        portrait.alpha = 0.45;
        add(portrait);

        border = new FlxSprite();
        border.frames = FlxAtlasFrames.fromSparrow(Frame1State.UI + "card.png", Frame1State.UI + "card.xml");
        border.animation.addByPrefix("idle", "card-unselect", 0, false);
        border.animation.addByPrefix("active", "card-select", 0, false);
        border.animation.play("idle");
        add(border);

        valueText = new FlxText(112, 154, 32, "0");
        valueText.setFormat(null, 38, FlxColor.WHITE, FlxTextAlign.RIGHT);
        add(valueText);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (FlxG.mouse.overlaps(this))
        {
            owner.showCharacterInfo(this);
            if (FlxG.mouse.justPressed)
                owner.changeAI(index, FlxG.keys.pressed.SHIFT ? -1 : 1);
            if (FlxG.mouse.justPressedRight)
                owner.changeAI(index, -1);
        }
    }

    public function setAI(value:Int):Void
    {
        valueText.text = Std.string(value);
        portrait.alpha = value > 0 ? 1 : 0.45;
        border.animation.play(value > 0 ? "active" : "idle");
    }
}

class TextButton extends FlxSpriteGroup
{
    var bg:FlxSprite;
    var callback:Void->Void;

    public function new(x:Float, y:Float, w:Int, h:Int, label:String, callback:Void->Void)
    {
        super(x, y);
        this.callback = callback;
        bg = new FlxSprite();
        bg.makeGraphic(w, h, 0xee001b3a);
        add(bg);
        var t = new FlxText(0, 5, w, label);
        t.setFormat(null, label.indexOf("\n") >= 0 ? 28 : 24, FlxColor.WHITE, FlxTextAlign.CENTER);
        add(t);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        bg.alpha = FlxG.mouse.overlaps(this) ? 1 : 0.82;
        if (FlxG.mouse.overlaps(this) && FlxG.mouse.justPressed)
            callback();
    }
}

class ImageButton extends FlxSpriteGroup
{
    var image:FlxSprite;
    var callback:Void->Void;

    public function new(x:Float, y:Float, asset:String, callback:Void->Void)
    {
        super(x, y);
        this.callback = callback;
        image = new FlxSprite();
        image.loadGraphic(asset);
        add(image);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        image.alpha = FlxG.mouse.overlaps(this) ? 1 : 0.88;
        if (FlxG.mouse.overlaps(this) && FlxG.mouse.justPressed)
            callback();
    }
}

class ToggleBox extends FlxSpriteGroup
{
    var checked:Bool;
    var callback:Bool->Void;
    var check:FlxSprite;

    public function new(x:Float, y:Float, label:String, checked:Bool, callback:Bool->Void)
    {
        super(x, y);
        this.checked = checked;
        this.callback = callback;
        var t = new FlxText(0, 0, 74, label);
        t.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER);
        add(t);
        check = new FlxSprite(30, 36);
        check.frames = FlxAtlasFrames.fromSparrow(Frame1State.UI + "checkbox.png", Frame1State.UI + "checkbox.xml");
        check.animation.addByPrefix("off", "uncheck", 0, false);
        check.animation.addByPrefix("on", "check", 0, false);
        add(check);
        refresh();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (FlxG.mouse.overlaps(this) && FlxG.mouse.justPressed)
        {
            checked = !checked;
            callback(checked);
            refresh();
        }
    }

    function refresh():Void
    {
        check.animation.play(checked ? "on" : "off");
    }
}

typedef CharacterData =
{
    var name:String;
    var id:String;
    var image:String;
    var description:String;
}

enum Frame1Popup
{
    None;
    Offices;
    PowerUps;
    Challenges;
}
