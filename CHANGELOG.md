# Änderungen in Sku-Ever

Neueste Version zuerst. Jede neue Version erhöht die Nummer um 0.01. Ab 0.29 beginnt jede Version mit einer Kurzfassung; danach steht zu jeder Änderung, was sich ändert und wie es umgesetzt ist.

## Sku-Ever 0.30 (14.11.2026)

### Kurzfassung
- Atem beim Tauchen wird wieder angesagt, alle 6 Sekunden.
- Neue Taste "minikarte vorlesen" (Strg+F): liest die Minikarte einmal aus und sagt alles an, was darauf zu sehen ist.
- Kräuter- und Erzsuche (Strg+Shift+F und Strg+Shift+R) funktioniert wieder, dein Begleiter wird dabei aussortiert.
- Die automatische Ressourcen-Ansage beim Laufen ist entfernt und durch die neue Taste ersetzt.
- Hintergrund für alles: Seit dem Spielupdate vom 13.11.2026 gibt WoW: Forever die Namen auf der Minikarte und weitere Werte nur noch als geheime Werte an Addons heraus.

### Hintergrund: geheime Werte
WoW: Forever läuft auf der neuen Spiel-Engine. Seit dem 13.11.2026 bekommen Addons einige Werte als "geheime Werte" (secret values). Ein Addon darf sie nicht lesen, nicht vergleichen, nicht zerlegen und nicht damit rechnen; jeder Versuch bricht mit einem Lua-Fehler ab ("attempt to perform string conversion on a secret string value"). Erlaubt sind nur: prüfen, ob überhaupt etwas da ist, Texte zusammensetzen (string.format) und die Übergabe an die Sprachausgabe des Spiels. Bei Zahlen ist zusätzlich die Umrechnung über eine Kurve des Spiels erlaubt (C_CurveUtil). Betroffen sind unter anderem alle Namen auf der Minikarte, auch die von Kräutern und Erzen. Erkannt werden geheime Werte mit issecretvalue (in Sku: Sku.IsSecret). Gesprochen werden sie über SkuVoice:SpeakSecretText, die einzige Stelle in Sku, die geheime Texte an die Blizzard-Sprachausgabe weiterreicht. WowVision hat seinen Minikarten-Scanner aus demselben Grund am 13.11. ganz abgeschaltet.

### Neu: Atem beim Tauchen alle 6 Sekunden
Was: Solange dein Charakter unter Wasser ist, sagt Sku-Ever alle 6 Sekunden "Atem" und den Prozentwert, zum Beispiel "Atem 80". Mit Wasseratmung bleibt die Ansage still.
Wie: Die Ansage hängt nicht mehr an den Ereignissen des Atembalkens (MIRROR_TIMER_START und Co.), die Sku auf WoW: Forever nicht mehr zuverlässig erreichten, sondern am Charakterstatus. In der Statusschleife (SkuCore/Core.lua, läuft etwa alle 0,15 Sekunden) startet IsSubmerged() einen 6-Sekunden-Takt, der beim Auftauchen endet. Bei jedem Takt fragt SkuCore:AnnounceBreath das Spiel neu: GetMirrorTimerInfo liefert die volle Länge des Atembalkens, GetMirrorTimerProgress("BREATH") die verbleibenden Millisekunden. Ist der Wert lesbar, rechnet Sku den Prozentwert aus. Ist er geheim, geht er durch eine Kurve von 0 bis 100 (C_CurveUtil, dasselbe Verfahren wie bei der Lebensansage des Begleiters) und von dort direkt an die Sprachausgabe. Gibt das Spiel gar nichts heraus, wird der Wert aus der Zeit unter Wasser berechnet (eine Minute Atem, wenn das Spiel keine Länge nennt). Zeigt die Liste der Balken lesbar keinen Atembalken, bleibt die Ansage still.

### Neu: Erschöpfung und Totstellen alle 6 Sekunden
Was: Der Erschöpfungsbalken im tiefen Wasser und der Totstellen-Balken werden alle 6 Sekunden mit ihrem Prozentwert angesagt.
Wie: Die alte Balken-Ansage in SkuCore/aq.lua rechnete in der Überwachungsschleife mit dem Balkenwert und brach bei einem geheimen Wert ab; dabei konnte sie die Lebens- und Gruppenüberwachung im selben Ablauf mitreißen. Neu ist Aq:MirrorBarsTick: ein fester 6-Sekunden-Takt je Balken, der Wert lesbar oder aus Startwert, Geschwindigkeit und Laufzeit berechnet, Pausen werden abgezogen. Der Atembalken ist hier ausgenommen, er kommt aus dem Charakterstatus (siehe oben), damit nichts doppelt kommt. Der Aufruf läuft unter pcall, ein Fehler hier stoppt keine andere Überwachung mehr.

### Neu: Taste "minikarte vorlesen" (Strg+F)
Was: Ein Tastendruck liest die Minikarte einmal aus und sagt alles an, was darauf in Reichweite steht: Kräuter, Erze, Quests, NPCs. Ist nichts da, kommt "Nichts auf der Minikarte". Nur außerhalb des Kampfes. Die Taste liegt im Sku-Menü unter den Tastenbelegungen bei den Ressourcen-Tasten (SKU_KEY_MMREAD) und lässt sich dort ändern; bestehende Profile bekommen sie beim nächsten Laden automatisch.
Wie: MinimapScanner:MinimapReadAll in SkuCore/minimapScanner.lua. Der Mauszeiger wird in die Bildschirmmitte gesetzt, die Minikarte auf 15 mal 15 Pixel verkleinert, unsichtbar gemacht und genau unter den Zeiger gelegt. So liegen alle Punkte in Reichweite unter dem Zeiger, und das Spiel nennt sie alle zusammen in seinem Minikarten-Tooltip. Damit kein anderes Fenster den Mauszeiger abfängt, liegt die Minikarte dabei ganz oben, ohne Klicks, mit versteckten Unter-Symbolen anderer Addons. Gelesen wird zuerst aus C_TooltipInfo.GetMinimapMouseover, sonst aus dem GameTooltip, bis zu sechs Mal mit einem Pixel Verschiebung, bis das Spiel etwas nennt. Danach wird alles zurückgestellt, auch der Zoom; eine Sicherung nach 4 Sekunden stellt die Minikarte in jedem Fall zurück. Gesprochen wird alles in einer Ansage über SpeakSecretText. Die Suchen auf der Minikarte bleiben unverändert.

### Geändert: Kräuter- und Erzsuche (Strg+Shift+F weit, Strg+Shift+R nah)
Was: Die Suche funktioniert wieder. Gefundene Ressourcen werden mit Nummer, Name, Richtung und Entfernung angesagt, die ersten vier als Schnellwegpunkte auf Umschalt+F5 bis F8 gesetzt. Alle Funde kommen in einer gemeinsamen Ansage.
Wie: Die Suche fährt wie bisher ein Raster über die Minikarte und liest an jedem Punkt, was das Spiel dort nennt. Neu: Ist der Name geheim, kann er nicht mehr mit der Kräuterliste verglichen werden. Stattdessen gilt jeder benannte Punkt als Fund. Treffer, die nah beieinander liegen (gleiche Regel wie bisher, 20 Einheiten), werden zu einer Gruppe zusammengefasst, und die Gruppe behält den ersten geheimen Namen. Weil SpeakSecretText eine Ansage ersetzt statt sie einzureihen, werden alle Gruppen zu einem Satz zusammengesetzt: Nummer, Name als Platzhalter, Richtung, Meter. Während der Suche sind nur die Suchzauber aktiv (Kräutersuche, Mineraliensuche); alle anderen Minikarten-Symbole werden kurz ausgeschaltet und danach wieder eingeschaltet. Die Suchzauber selbst werden nie angefasst.

### Neu: Begleiter wird bei der Suche aussortiert
Was: Dein Begleiter (zum Beispiel ein Dämon) steht auf der Minikarte und wurde als Fund angesagt und als Wegpunkt gesetzt. Ein Fund näher als 10 Meter an dir gilt jetzt als Begleiter, solange einer draußen ist, und fällt heraus.
Wie: Am Ende des Rasters (MinimapScanner:FinishGridScan) wird für jede Gruppe mit geheimem Namen die Entfernung zur Kartenmitte berechnet (dieselbe Umrechnung wie für die Meterangabe). Ist UnitExists("pet") wahr und die Gruppe näher als PET_DROP_METERS (10 Meter), wird sie verworfen, bevor angesagt oder ein Wegpunkt gesetzt wird.

### Entfernt: automatische Ressourcen-Ansage beim Laufen
Was: Die Einstellung "bei ressourcen benachrichtigen" hat beim Laufen neue Ressourcen angesagt. Sie ist durch die Taste "minikarte vorlesen" ersetzt. Die Umschalttaste der alten Ansage sagt jetzt, dass sie ersetzt ist.
Wie: Kräuternamen sind ebenfalls geheim, deshalb lässt sich nicht mehr erkennen, ob ein Punkt eine Ressource ist. Die automatische Ansage hätte beim Laufen ständig alles auf der Minikarte angesagt, auch den Begleiter. Der Taktgeber in MinimapScannerOnLogin startet die Ansage nicht mehr. Die Sammelroute (SkuCore/gatherRoute.lua) verließ sich auf diese Ansage und prüft die Ressourcen jetzt immer selbst.

### Fehler behoben
- Kräutersuche brach mit "attempt to perform string conversion on a secret string value" ab. Wie: Jede Stelle, die Minikarten-Namen liest, prüft vorher mit Sku.IsSecret, ob der Name geheim ist, und behandelt ihn dann wie oben beschrieben.
- Nach diesem Abbruch blieb die Minikarte verschoben und verkleinert unter dem Mauszeiger hängen. Wie: Der Leseschritt des Rasters läuft unter pcall; ein Fehler gilt als "nichts gefunden", und das Raster läuft zu Ende und stellt die Minikarte zurück.
- Die Atem-Ansage beim Tauchen kam nicht mehr (siehe oben).
- Ein Fehler in der Balken-Ansage konnte die Lebens- und Gruppenüberwachung stoppen (siehe oben).

### Während der Arbeit verworfen
- Eine Gegenprobe, die die Kräutersuche kurz aus- und wieder einschaltete, um NPCs von Kräutern zu unterscheiden. Das Spiel lässt ein Addon den Suchzauber zwar ausschalten, aber nur auf Tastendruck wieder einschalten; die Gegenprobe ließ deshalb die Kräutersuche ausgeschaltet zurück. Der Code ist abgeschaltet und wird nie mehr erreicht.
- Zählen der Tooltip-Zeilen, um mehrere Namen zu erkennen: Das Spiel schreibt alle Namen in eine einzige Zeile.

### Bekannt
- Ein Kraut lässt sich am Namen nicht erkennen, solange das Spiel die Namen geheim hält. Die Suche mit Strg+Shift+F kann außer dem Begleiter weiterhin NPCs ansagen und als Wegpunkt setzen, die das Spiel unabhängig von der Suche auf der Minikarte zeigt, zum Beispiel für Quests.
- Die Filter für einzelne Kräuter und Erze im Sku-Menü greifen bei geheimen Namen nicht mehr. Welche Ressourcen erscheinen, bestimmt die aktive Suche.
- Die Sammelroute bekommt bei geheimen Namen keine Bestätigung mehr aus dem Minikarten-Scan.

### Downloads
- Sku-Ever-Spielordner.zip: das Addon mit den Ordnern Sku, SkuPacks, SkuEngineEK und SkuEngineZW.
- Sku-Ever-0.30.zip, SkuPacks.zip, SkuEngineEK.zip, SkuEngineZW.zip: dieselben Teile einzeln, werden vom Installer benutzt. SkuPacks und die Engine-Daten sind unverändert gegenüber 0.28.
- Installer 1.2, unverändert. Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26.

### Hinweis zum Stand
- Getestet im Spiel: Atem-Ansage beim Tauchen, Taste "minikarte vorlesen", Kräutersuche findet Kräuter.
- Noch nicht im Spiel getestet: Aussortieren des Begleiters nach Entfernung, Erschöpfung und Totstellen.

## Sku-Ever 0.29 (14.11.2026)

### Kurzfassung
- Esc öffnet das originale Spielmenü, "Optionen" das originale Einstellungsfenster des Spiels, beide bedienbar wie ein Fenster.
- Esc-Fix: Das Sku-Spielmenü schloss sich sofort wieder.
- Startprofil für Erstinstallationen.
- Installer 1.2: aktualisiert sich auch als heruntergeladene Kopie selbst.

### Neu: originales Spielmenü auf Esc
Was: Esc öffnet das Spielmenü des Spiels statt eines Eintrags im Sku-Menü. Tab und Umschalt+Tab (oder Pfeil hoch und runter) gehen durch die Schaltflächen, Enter drückt sie, ein zweites Esc schließt das Menü. Buchstaben springen zur nächsten passenden Schaltfläche. "Makros" und "AddOns" führen weiter in die Sku-Menüs, weil die originalen Fenster dafür nicht lesbar sind.
Wie: Neuer Baustein "Native windows" am Ende von SkuCore/gameOptions.lua. Der Esc-Haken (SkuCore:GameMenuShowHandler) versteckt das Blizzard-Menü nicht mehr, sondern startet eine Fenster-Sitzung. Die Tasten kommen über Vorrang-Tastenbelegungen (SetOverrideBindingClick) auf einen eigenen Knopf (SkuNativeWinKey) und zählen damit als echte Tastendrücke; so dürfen auch Ausloggen und Spiel beenden ausgelöst werden. Die Schaltflächen werden live aus dem GameMenuFrame gelesen und nach ihrer Lage sortiert. Endet das Menü, werden die Tastenbelegungen gelöscht. Im Kampf bleibt es beim bisherigen Weg über das Sku-Spielmenü, weil Tastenbelegungen im Kampf nicht geändert werden dürfen.

### Neu: originales Einstellungsfenster auf "Optionen"
Was: Das Einstellungsfenster des Spiels ist bedienbar wie ein Fenster mit Stopps: Reiter (nur wenn das Spiel sie zeigt), Suchen, Kategorien, die Einstellungen der gewählten Kategorie, Standard. Tab wechselt den Stopp, Pfeil hoch und runter gehen durch die Einträge, Enter schaltet Kontrollkästchen um und öffnet Auswahllisten, Pfeil links und rechts verstellen Schieberegler, Enter auf einem Schieberegler öffnet ein Feld für eine genaue Zahl, die Leertaste liest den Tooltip. Das Fenster öffnet im Suchfeld; Enter im Suchfeld springt zu den Treffern. Das Sku-Menü "Spieloptionen" bleibt unverändert.
Wie: Dieselbe Fenster-Sitzung, gestartet über einen Haken auf das Erscheinen von SettingsPanel. Kategorien und Einstellungen werden aus den Datenlisten des echten Fensters gelesen (ScrollBox-DataProvider), so stimmen auch Suchtreffer. Werte werden über dieselben Hilfsfunktionen geschrieben wie im Sku-Menü (ApplySetting mit sofortigem Übernehmen, OptionList, SliderInfo), beide Wege verhalten sich also gleich. Das Suchfeld ist das echte Suchfeld des Spiels; Sku setzt nur den Fokus hinein, weil ein Text, den ein Addon hineinschreibt, die Suche des Spiels blockieren würde. Grundlage war das Verhalten, das das WowVision-Handbuch beschreibt; Code wurde nicht übernommen, weil WowVision keine Lizenz hat.

### Fehler behoben: Sku-Spielmenü schloss sofort wieder
Was: Esc öffnete das Sku-Spielmenü, gleich danach kam "Menü geschlossen".
Wie: Esc versteckt das Blizzard-Spielmenü; dadurch lief die Fensterprüfung SkuCore:CheckFrames (Zweig "No contributing window is open"), sah kein offenes Fenster und schloss das gerade geöffnete Sku-Menü. Die Prüfung schließt jetzt nur noch, wenn keine Spielmenü-Sitzung läuft (SkuCore.gameMenuActive). Gilt weiter für den Weg im Kampf.

### Neu: Startprofil für Erstinstallationen
Was: Wer Sku-Ever zum ersten Mal installiert, bekommt erprobte Grundeinstellungen. Vorhandene Einstellungen bleiben unberührt.
Wie: Sku/SkuEverStartProfile.lua enthält ein Einstellungsprofil ohne persönliche Daten (ohne Chatverlauf, Wegpunkte und Tastenzuordnungen). SkuZOptions/Core.lua legt es nur an, wenn auf dem WoW-Konto noch gar keine Sku-Einstellungen existieren (SkuOptionsDB fehlt).

### Neu: Installer 1.2
Was: Auch eine heruntergeladene, ältere Kopie des Installers prüft jetzt beim Start, ob es eine neuere Fassung gibt.
Wie: Bisher prüfte nur die feste Kopie im Updater-Ordner, die die Verknüpfung "Sku-Ever Updater" startet. Jetzt prüft jede Kopie; eine heruntergeladene lädt die neue Fassung in den festen Updater-Ordner, prüft sie gegen die veröffentlichte Prüfsumme und startet sie von dort. Die heruntergeladene Datei selbst bleibt unverändert. Neuer Selbsttest "downloadedcopy".

### Downloads
- Sku-Ever-Spielordner.zip: das Addon mit den Ordnern Sku, SkuPacks, SkuEngineEK und SkuEngineZW.
- Sku-Ever-0.29.zip, SkuPacks.zip, SkuEngineEK.zip, SkuEngineZW.zip: dieselben Teile einzeln, werden vom Installer benutzt. SkuPacks und die Engine-Daten sind unverändert gegenüber 0.28.
- Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26.

### Hinweis zum Stand
- Getestet im Spiel: Esc öffnet das Spielmenü, Optionen das Einstellungsfenster.
- Noch nicht im Spiel getestet: das Startprofil bei einer Erstinstallation, Sonderfälle im Einstellungsfenster (Grafikqualität, Farbfelder, Tastenbelegungen).

## Sku-Ever 0.28 (14.11.2026)

Neu gegenüber 0.27 (Engine 7)
- Routen in neuen Gebieten: Rotkamm, Dämmerwald, Dun Morogh, Loch Modan und das Sumpfland haben jetzt Engine-Routen. Rotkamm und Dämmerwald gehören zur Gruppe von Sturmwind, Elwynn und Westfall (SkuEngineEK). Eisenschmiede, Dun Morogh, Loch Modan und Sumpfland bilden eine zweite Gruppe (neues Addon SkuEngineZW). Routen über die Gebietsgrenzen innerhalb einer Gruppe funktionieren.
- Wichtige Ziele verschwinden nicht mehr aus den Routenlisten: Dungeon-Eingänge, Schiffe und Anleger, Questgeber sowie Monster und Objekte, die Ziel einer Quest sind. Sie werden nur noch ausgeblendet, wenn Sku selbst einen Wegpunkt mit gleichem Namen direkt daneben hat.
- Sturmwind und Eisenschmiede: Questgeber und Quest-Ziele stehen jetzt auch in den Engine-Listen.
- Einstiegspunkte (Umschalt+F10 und Nahe Routen): wo die Engine liegt, sind es 4 Sku-Punkte und darunter bis zu 3 Engine-Punkte (am Ende "Engine"); hat Sku dort keine, bis zu 6 Engine-Punkte. Wo es keine Engine-Daten gibt, bleibt es bei der alten Anzahl.
- Die Ebenenfrage gilt auch für Engine-Einstiegspunkte. Ist die Höhe unklar, wird nun nach der Ebene gefragt statt "Höhe unklar" zu melden.
- Questgeber und Quest-Ziele stehen nicht mehr doppelt in den Listen, wenn Sku sie schon hat (z. B. Greifenmeister): Namen mit Rollenzusatz in Klammern wie "Thor (Greifenmeister)" werden jetzt mit Skus Namen gleichgesetzt.
- Kräuter und Erz stehen nicht mehr mitten in Städten (Eisenschmiede, Sturmwind).
- Es wird nur noch die Engine-Gruppe geladen, in der du gerade stehst (spart Speicher und Ladezeit).

### Fehler behoben
- Eine laufende Route brach ab, wenn man währenddessen ein Routenmenü (Einstiegspunkte) öffnete. Sie läuft jetzt weiter.

### Downloads
- Sku-Ever-Spielordner.zip: das Addon mit den Ordnern Sku, SkuPacks, SkuEngineEK und SkuEngineZW.
- Sku-Ever-0.28.zip, SkuPacks.zip, SkuEngineEK.zip, SkuEngineZW.zip: dieselben Teile einzeln, werden vom Installer benutzt.
- Installer 1.1: installiert auch das neue Addon SkuEngineZW. Ältere Installer aktualisieren sich selbst. Wer von Hand installiert, kopiert den neuen Ordner SkuEngineZW mit.
- Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26.

### Hinweis zum Stand
- Getestet im Spiel: Engine-Ziele und Einstiegspunkte in Sturmwind, Elwynn, Westfall und Eisenschmiede, Laden beider Gruppen.
- Noch nicht ausführlich im Spiel getestet: Routen in Rotkamm, Dämmerwald, Dun Morogh, Loch Modan und im Sumpfland sowie der Fix für den Routen-Abbruch.

### Bekannt
- Die neuen Engine-Gruppen brauchen beim ersten Laden etwas Speicher (je nach Gruppe etwa 100 bis 200 MB, solange man dort ist).
- Eisenschmiede: Die Route von der Halle der Thane zur Tiefenbahn meldet "Höhe unklar".

## Sku-Ever 0.27 (13.11.2026)

Neu gegenüber 0.26
- Ebenenfrage: Ist in Sturmwind und anderen Gebäuden die Etage unklar, fragt Sku-Ever beim Einstiegspunkt (Umschalt+F9 und Umschalt+F10), auf welcher Ebene du bist. Danach startet die Route von dieser Ebene.
- Platzhalter-NPCs ausgeblendet: Unsichtbare Markierungs-NPCs (zum Beispiel die Klassenlehrer-Attrappen in Sturmwind, Trigger- und Stalker-Einträge) tauchen nicht mehr als Wegpunkte auf. Betrifft alle Gebiete.
- Quest-Korrekturen: Bei 174 Quests, die bisher keinen nutzbaren Geber, keine Abgabe oder keine Ziele hatten, sind diese jetzt ergänzt. Es wurden nur Quests übernommen, bei denen alle Orte auch erreichbar sind.
- Datenpaket neu aus der Questie-Datenbank 1.1.0: 1631 Quests (vorher 1503), 3233 NPCs (vorher 3136) und 638 Objekte, dazu verbesserte Zuordnung von Gebern, Abgaben und Zielen sowie neue deutsche Namen.
- Elwynn: Routendaten (SkuEngineEK) aktualisiert.

### Fehler behoben
- Fehler beim Öffnen einer Route, wenn für den gewählten Wegpunkt kein Rückweg vorhanden war (SkuNav).
- Fehler im Chat bei geheimen Spielernamen (Flüstern, SkuChat).

### Downloads
- Sku-Ever-Spielordner.zip: das Addon mit den Ordnern Sku, SkuPacks und SkuEngineEK.
- Sku-Ever-0.27.zip, SkuPacks.zip, SkuEngineEK.zip: dieselben Teile einzeln, werden vom Installer benutzt.
- Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26 (Download über die Homepage oder den Installer).

### Installieren
Am einfachsten mit dem Sku-Ever-Installer. Von Hand: WoW schließen, Spielordner-ZIP entpacken, die Ordner nach World of Warcraft\_forever_\Interface\AddOns kopieren und alte Ordner ersetzen. Deine Einstellungen bleiben erhalten.

### Hinweis zum Stand
- Die Ebenenfrage und das Ausblenden der Platzhalter-NPCs sind im Spiel getestet.
- Das neue Datenpaket und die Elwynn-Daten sind noch nicht ausführlich im Spiel getestet.

### Bekannt
- Eisenschmiede: Die Route von der Halle der Thane zur Tiefenbahn meldet "Höhe unklar".
- Manche neuen NPCs haben nur englische Namen.
- Einzelne Quests aus der Datenbank haben einen Geber, der im Spiel (noch) nicht auftaucht, zum Beispiel "Lesezimmer" in Sturmwind.

## Sku-Ever 0.26

Erste Version unter dem Namen Sku-Ever. Inhaltlich gleich mit Sku Forever 2.6 von gitana83.

- Name in der Addon-Liste: Sku-Ever 0.26.
- Versionsnummer 0.26.
- Der Versionsabgleich im Spiel läuft über einen eigenen Kanal. Sku-Ever vergleicht sich nur mit anderen Sku-Ever-Spielern und meldet keine falschen Updates wegen anderer Sku-Versionen.
