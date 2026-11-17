# Änderungen in Sku-Ever

Neueste Version zuerst. Jede neue Version erhöht die Nummer um 0.01. Ab 0.29 beginnt jede Version mit einer Kurzfassung; danach steht zu jeder Änderung, was sich ändert und wie es umgesetzt ist.

## Sku-Ever 0.42 (17.11.2026)

### Kurzfassung
- "Optionen Audiounterstützung" steht im Schnellmenü jetzt an dritter Stelle, direkt nach Sprachausgabe.
- Neue Installationen starten in den Ziel Optionen mit genau vier eingeschalteten Punkten.
- Das Installer-Startskript lädt jetzt aus Sku-Ever statt aus dem alten Repository.

### Geändert: Position im Schnellmenü
Was: Die Reihenfolge im Schnellmenü ist jetzt Lautstärke, Sprachausgabe, Optionen Audiounterstützung, Dial Targeting, Soft Targeting, Sonstiges. In 0.41 standen Dial Targeting und Soft Targeting davor.
Wie: Der Block 7.3 in SkuZOptions/Core.lua steht jetzt vor dem Einhängen von Dial Targeting und Soft Targeting; die Menüreihenfolge folgt der Einfügereihenfolge.

### Geändert: Startprofil, Ziel Optionen
Was: Eine Neuinstallation hat unter Monitor, Ziel Optionen nur diese Punkte an: Im Kampf für Spieler nicht Freundlich oder Feindlich und Level ansagen; Freundliche und feindliche Spieler ansagen; Spieler mit generischen Beschreibungen ansagen; Blizzard Zielname Ansage automatisch regeln. Nur Schlachtzugsymbol ansagen, Schlachtzugsymbole wiederholen und Sku-Schlachtzugsymbole automatisch setzen sind aus. Bestehende Einstellungen bleiben unverändert.
Wie: Abschnitt SkuMob in SkuEverStartProfile.lua setzt alle sieben Schalter ausdrücklich.

### Behoben: alte Verweise auf das frühere Repository
Was: Das Startskript installer/bootstrap/Install-SkuUpdater.ps1 lud aus Sku75/Sku-WoW-Addon-TBC und suchte SkuInstaller.exe; jetzt lädt es Sku-Ever-Installer.exe aus Sku75/Sku-Ever. Sku/README.md, die Login-Tool-Anleitung, das alte Release-Skript und die Installer-Dokumente zeigen auf Sku-Ever.
Wie: Textersetzungen; installer/shared/addon-catalog.json nennt jetzt Sku75/Sku-Ever, Sku-Ever-{version}.zip und den Begleitpaket-Tag v0.26 (das nicht angebotene Paket SkuAudioData entfernt), damit test_catalog_parity.py wieder besteht. Der Installer selbst ist unverändert (1.6), er liest diese Felder nicht.

### Behoben: Selbsttest des Installers
Was: SkuSelfTest selfupdateproof lud die nicht mehr vorhandene Datei SkuInstaller.exe; forevertest prüfte noch Anniversary, Era und die alten Versionsnummern 43/44. Beide laufen jetzt durch.
Wie: SelfTestProgram.cs nutzt Sku-Ever-Installer.exe, forevertest prüft nur noch Forever und 0.xx-Versionen.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.42.zip: mit den Änderungen.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.41.

## Sku-Ever 0.41 (17.11.2026)

### Kurzfassung
- Im Schnellmenü (unterster Punkt im Sku-Menü) steht als dritter Punkt "Optionen Audiounterstützung". Darin stellst du Blizzards Kampf-Audiohinweise ein, ohne durch das ganze Spielmenü zu gehen: Allgemein, eigene Gesundheit, eigene Ressource und Gesundheit des Ziels.

### Neu: Optionen Audiounterstützung im Schnellmenü
Was: Neuer Punkt im Schnellmenü zwischen Sprachausgabe und Sonstiges. Er ist eine Fernbedienung für die Kampf-Audiohinweise aus dem Spielmenü (Optionen, Audiounterstützung); jede Änderung gilt auch dort und umgekehrt.
- Allgemein: Hauptschalter, Sprechgeschwindigkeit, Kampfbeginn ansagen, Kampfende ansagen, Zielnamen ansagen.
- Eigene Gesundheit ansagen: die Einstellung selbst (Aus oder alle 10 bis 50 Prozent), dann Format, Stimme, Drosselung und Lautstärke.
- Eigene Ressource ansagen (Name je nach Ressource, zum Beispiel Mana): dieselben Unterpunkte. Zeigt das Spiel eine zweite Ressource an, bekommt sie ein eigenes Untermenü.
- Gesundheit des Ziels ansagen: die Einstellung selbst, dann Format, Wenn das Ziel stirbt, Stimme, Drosselung und Lautstärke.
Namen und Werte kommen aus dem Spiel und stehen damit in der Sprache des Clients. Steht eine Ansage auf Aus, sagen ihre Unterpunkte "deaktiviert".
Wie: Neue Funktion GameOptions:AudioAssistMenuBuilder in SkuCore/gameOptions.lua. Sie sucht in Blizzards Einstellungen die Kategorie mit der Einstellung CAAEnabled, nimmt die Zeilen über ihre Variablen (CAAEnabled, PROXY_CAA_SPEED, CAASayCombatStart, CAASayCombatEnd, CAASayTargetName; CAAPlayerHealthPercent, PROXY_CAA_PLAYER_RESOURCE_1_PERCENT, PROXY_CAA_PLAYER_RESOURCE_2_PERCENT, CAATargetHealthPercent) und hängt unter jede Ansage die Zeilen, die Blizzard ihr per SetParentInitializer zuordnet. Gebaut werden die Einträge mit demselben BuildInitializer wie im Spieloptionen-Abbild. Eingehängt in SkuZOptions/Core.lua (Schnellmenü, Abschnitt 7.3), Menüname ACC_AudioAssistTitle in deDE, enUS und frFR.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.41.zip: mit dem neuen Menü.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.40.

### Hinweis zum Stand
- Im Spiel noch nicht getestet. Die Variablennamen stammen aus Blizzards Classic-Code; weicht WoW: Forever bei einem Namen ab, fehlt das betreffende Untermenü.

## Sku-Ever 0.40 (17.11.2026)

### Kurzfassung
- Der Chat (Shift+F2) lässt sich wieder bedienen, auch wenn ein Reiter noch leer ist. Ein leerer Reiter sagt jetzt seinen Namen und "Leer", der Wechsel zu anderen Reitern funktioniert immer.

### Behoben: Fehler im Chat bei leeren Reitern
Was: Ein neuer Charakter hat vier Chat-Reiter (Standard, Kommunikation, Anderes, Flüstern), die leer sind, bis die erste passende Nachricht kommt. Öffnete man den Chat mit Shift+F2 auf einem leeren Reiter, blieb Sku stumm. Jede weitere Chat-Taste (Pfeil hoch, Pfeil runter, Strg+Enter und auch Pfeil links und rechts zum Reiterwechsel) erzeugte einen Lua-Fehler, der Chat ließ sich nicht mehr lesen. Jetzt sagt ein leerer Reiter beim Öffnen und beim Wechsel seinen Namen und "Leer". Pfeil hoch, Pfeil runter und Strg+Enter sagen auf einem leeren Reiter nur "Leer". Pfeil links und rechts wechseln immer den Reiter. Fehlen die Reiter ganz, legt Sku sie beim Öffnen des Chats neu an.
Wie: In SkuChat/Core.lua las der Klick-Handler der Chattasten (OnSkuChatToggle OnClick) die aktuelle Zeile und griff ohne Prüfung auf tLineData.itemLinks zu; bei leerer History war tLineData nil. Jetzt fängt der Handler das ab: Hoch, Runter und Strg+Enter lesen nur "Leer" vor, alle anderen Tasten laufen mit einer leeren Zeile weiter. SkuChat:ReadLine sagt bei leerem Reiter "Leer", beim Reiterwechsel mit dem Reiternamen davor. Das Anlegen der Standardreiter ist aus PLAYER_ENTERING_WORLD in die neue Funktion SkuChat:CreateDefaultTabsIfMissing gezogen; OpenChat und der Klick-Handler rufen sie zusätzlich auf, falls die Einrichtung beim Betreten der Welt mit einem Fehler abgebrochen ist. Im Kampf legt sie von einer Chattaste aus keine Reiter an, weil die Reiter sichere Schaltflächen sind.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.40.zip: mit der Korrektur.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.39.

### Hinweis zum Stand
- Der Fix ist im Spiel noch nicht getestet. Den genauen Fehlertext des Testers kennen wir nicht; die Ursache passt zu seiner Beschreibung.

## Sku-Ever 0.39 (16.11.2026)

### Kurzfassung
- Auf WoW: Forever hörst du den Namen eines Ziels (Tab, Rundum-Zielwahl, Fokus) nicht mehr doppelt. Die Gegner-Lebenspunkte bleiben, in Instanzen bleibt Blizzards Namensansage an.
- Neuer Schalter unter Monitor, Ziel Optionen: "Blizzard Zielname Ansage automatisch regeln". Aus gibt dir die Einstellung des Spiels zurück.
- Ziele, die auf mehreren Ebenen stehen (zum Beispiel Wachtmeisterin Aonda und Coriella Calmbreeze in Zephras), werden pro Ebene angeboten, auch im Questbuch. Die Route endet auf der gewählten Ebene (Engine 17.2).
- Ein Menüeintrag "Questie" erzeugte beim Aufbau der Tastenbelegung einen Fehler im Protokoll. Das ist behoben.

### Behoben: Gegnername doppelt (nur WoW: Forever)
Was: Wer ein Ziel gewählt hat, hörte den Namen zweimal: einmal mit der Gesundheit, einmal mit Name und Stufe. Die erste Stimme ist die Kampf-Audioansage des Spiels (Combat Audio Alerts, "Zielname"), die zweite Sku. Zusätzlich sprach Sku den Namen bei einem Zielwechsel durch Weiche Interaktion doppelt aus.
Wie: SkuMob/Core.lua (ApplyBlizzardTargetName) stellt die Spiel-Einstellung CAASayTargetName außerhalb von Instanzen auf aus und in Instanzen auf an, nie im Kampf. Die Zielgesundheit des Spiels bleibt an. Die Doppelansage durch Weiche Interaktion ist über eine kurze Sperre je Ziel (0,6 s) und durch Weglassen des Namensteils in der Zielansage (innerhalb von 5 s) behoben.

### Neu: Schalter für die Blizzard-Namensansage
Was: Monitor, Ziel Optionen, "Blizzard Zielname Ansage automatisch regeln" (Standard: an). Ausgeschaltet stellt Sku die ursprüngliche Einstellung des Spiels wieder her, wer die Stimme des Spiels draußen mag, kann sie so zurückholen.
Wie: SkuMob/Options.lua (blizzardTargetNameAuto, blizzardTargetNameOriginal), Texte in locales deDE, enUS, frFR. Der Schalter gibt es nur auf Forever.

### Neu: Ziele auf mehreren Ebenen (Engine 17.2)
Was: Ein Ziel kann an derselben Stelle mehrere feste Knoten haben, einen pro Ebene. Die Engine nahm bisher immer den tiefsten. Jetzt steht es wie bei WowVision pro Ebene in den Listen ("Name, Ebene n von N"), im Questbuch und bei Nahe Routen gibt es unter jedem Einstiegspunkt einen Eintrag je Ebene, und die Route endet auf dem Knoten der gewählten Ebene. Ohne Wahl nimmt sie die kürzeste Route über alle Knoten.
Wie: SkuNav/EngineRoute.lua (tNodesAt, Engine:TargetFloors, tExpandTargetFloors, Route mit Zielhöhe), SkuNav/Options.lua (AddEngineEntryPointsForTargets, targetZ). Gilt nur in den Gebieten mit Merkmal wv.

### Behoben: Menüeintrag "Questie"
Was: Beim Aufbau der Tastenbelegung wurde das Objekt des Addons Questie als Menüname genommen; im Protokoll stand "menu node without text name".
Wie: SkuCore/Options.lua prüft, dass die Kategorie-Konstante ein Text ist.

### Engine-Nummer
Engine 17.2.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.39.zip: mit den Änderungen.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.38.

### Hinweis zum Stand
Im Spiel bestätigt: kein doppelter Name außerhalb von Instanzen, Gegner-HP bleiben, der Schalter wirkt in beide Richtungen; Ebenenwahl bei Aonda (Questbuch) und Coriella (Ziele-Liste). Noch nicht getestet: der Name in Instanzen (einmal, doppelt oder gar nicht).

## Sku-Ever 0.38 (16.11.2026)

### Kurzfassung
- Verkaufen im Auktionshaus funktioniert wieder. Sku rundet jeden Preis auf ganze Silber, weil das Auktionshaus von WoW: Forever Preise mit Kupfer ohne Antwort verwirft.

### Behoben: Einstellen im Auktionshaus blieb stumm und blockierte das Auktionshaus
Was: Ein Gegenstand mit einem Preis in Kupfer (zum Beispiel 97 Kupfer) wurde nicht eingestellt. Sku sagte nichts, der Gegenstand blieb in der Tasche, und danach kam bei jedem weiteren Einstellen und bei Suchen nur noch "Bitte kurz warten und nochmal versuchen", bis zum nächsten Einloggen. Mit einem Preis von 1 Silber ging derselbe Gegenstand durch. Jetzt rundet Sku Sofortkaufpreis, Startgebot, den übernommenen Marktpreis und den Preis pro Stück aus dem Gesamtpreis auf das nächste ganze Silber, mindestens 1 Silber. Nach der Eingabe sagt Sku den gerundeten Preis an.
Wie: Das Verkaufsfenster des Spiels hat auf WoW: Forever kein Kupferfeld, das Auktionshaus nimmt nur ganze Silber an. C_AuctionHouse.SupportsCopperValues() meldet dort aber "ja", und nur dann hatte Sku bisher gerundet. Ein Post mit Kupfer ging deshalb unverändert an den Server, der ihn ohne Antwort verwarf; das Nachrichtensystem des Auktionshauses (IsThrottledMessageSystemReady) blieb danach belegt. In SkuCore/auctionHouseForever.lua rundet die neue Funktion tSilverOnly jetzt immer: bei der Preiseingabe (tParseMoney), beim Startgebot, beim Marktpreis, beim Gesamtpreis und noch einmal unmittelbar vor dem Einstellen (AHF:PostDraft). Gefunden mit vorübergehenden Protokollzeilen im Spiel, die nicht im Release sind.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.38.zip: mit der Korrektur.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.37.

### Hinweis zum Stand
- Getestet im Spiel: Mit einem Preis von 1 Silber ließ sich die Schriftrolle einstellen, mit 97 und 99 Kupfer nicht.
- Die Rundung selbst ist im Spiel noch nicht getestet.

## Sku-Ever 0.37 (16.11.2026)

### Kurzfassung
- Mit englischem Spiel-Client spricht Sku-Ever durchgehend Englisch. Neu ist dafür das englische Sprachpaket, der Installer 1.5 bietet es an.
- Eine Erstinstallation auf einem englischen Client bekommt das Startprofil in Englisch, die Rundum-Zielwahl bleibt dabei aus.
- Sieben Ansagen und Meldungen, die bisher nur Deutsch kannten, gibt es jetzt auch auf Englisch.
- Der Installer aktualisiert auch, während WoW läuft. Danach reicht /reload im Spiel.

### Nachtrag: Installer 1.6 (16.11.2026)
Was: Die heruntergeladene Datei Sku-Ever-Installer.exe richtet nur noch ein. Sie legt die feste Kopie unter %LOCALAPPDATA%\SkuEverUpdater ab, startet sie und beendet sich. Die feste Kopie legt die heruntergeladene Datei still in den Papierkorb und sagt auf dem ersten Bildschirm, dass Sku-Ever ab jetzt über die Desktop-Verknüpfung startet. Die Verknüpfung heißt jetzt "Sku-Ever installieren und aktualisieren" (englisch "Sku-Ever install and update"), die alte "Sku-Ever Updater" wird entfernt.
Warum: Eine heruntergeladene exe kann sich nicht selbst aktualisieren. Wer sie statt der Verknüpfung startete, blieb auf ihrer alten Nummer und bekam bei jedem Start erneut dieselbe Selbstaktualisierung angeboten.
Wie: Neue Datei installer/SkuInstaller/Bootstrap.cs. HandOff (Program.cs, ganz am Anfang) übergibt an die feste Kopie mit --remove-bootstrap und --bootstrap-pid. StartRemoval wartet, bis die heruntergeladene Datei beendet ist, und legt sie per SHFileOperation in den Papierkorb, nur wenn sie laut Versionsangaben ein Sku-Ever-Installer ist und nicht im Ordner der festen Kopie liegt. Ältere heruntergeladene Kopien (bis 1.5) übergeben nicht selbst; sie aktualisieren die feste Kopie und starten sie mit --self-updated. Dann erkennt die feste Kopie den startenden Prozess als heruntergeladenen Installer und entfernt ihn genauso. Shortcut.cs: neuer Name, alte Verknüpfungen mit unserem früheren Namen und unserem Ziel werden gelöscht.
Downloads: Nur Sku-Ever-Installer.exe und installer-version.txt im Release 0.37 sind ausgetauscht.

### Neu: Englisches Sprachpaket im Installer 1.5
Was: Der Installer bietet neben "SkuAudioData German Fast" jetzt "SkuAudioData English" an. Ist der Installer auf Englisch eingestellt, ist das englische Paket vorgewählt. Ein Update behält das Paket, das schon installiert ist. Die Homepage hat einen eigenen Download für die englische Sprachausgabe.
Wie: Das Paket ist SkuAudioData_en aus dem SkuAddon (Version 12, GPL), mit WoW-Version 16001 in der TOC. Es liegt wie die anderen Begleitpakete im Release v0.26. In installer/SkuInstaller/Config.cs steht es als zweites Sprachpaket, Program.cs wählt die Vorgabe nach der Installer-Sprache. Bisher gab es nur das deutsche Paket. Ein englischer Client fand dann kein passendes Paket: Die Sku-Stimme fiel auf die Windows-Sprachausgabe zurück, und die Aura-Klänge, die nur im Sprachpaket liegen, blieben stumm.

### Neu: Installer aktualisiert bei laufendem Spiel
Was: Der Installer verlangt nicht mehr, dass World of Warcraft geschlossen ist. Er aktualisiert auch bei laufendem Spiel, danach reicht /reload. Kam ein ganz neues Addon dazu (zum Beispiel eine neue SkuEngine-Gruppe), sagt die Zusammenfassung, dass das Spiel einmal neu gestartet werden muss, weil WoW neue Addon-Ordner nur beim Start findet. Erforderliche Spieleinstellungen schreibt er nur bei geschlossenem Spiel und sagt sonst, dass sie beim nächsten Lauf mit geschlossenem Spiel folgen.
Wie: In installer/SkuInstaller/ProgressForm.cs entfällt die Abfrage "Bitte World of Warcraft schließen". Bei laufendem Spiel überschreibt der Installer die Dateien an Ort und Stelle (OverwriteInPlace, gab es schon für Code-Updates), jetzt auch für Sprachpakete und neue Ordner. InstallRunner merkt sich, ob das Spiel lief (GameWasRunning), lässt dann GameSettings.Apply aus, weil das Spiel seine Config.wtf beim Beenden überschreibt, und wählt die passende Schlusszeile (neu: summary.restartNew und summary.settingsLater in Loc.cs, deutsch, englisch, französisch).

### Behoben: Startprofil auf einem englischen Client
Was: Das Startprofil für Erstinstallationen wurde auf einem deutschen Client gespeichert. Auf einem englischen Client schaltete es die Rundum-Zielwahl ein statt aus, der Tastenklang dazu blieb stumm, und Chat-Reiter und Übersichtsseiten hießen deutsch (zum Beispiel "Flüstern", "Allgemeines").
Wie: Einige Einstellungen speichert Sku als Text der Client-Sprache, etwa "Aus" oder die Namen der Chat-Reiter. Am Ende von Sku/SkuEverStartProfile.lua nennt die Tabelle SkuEverStartProfileLocaleKeys zu jedem dieser deutschen Werte den Schlüssel der Sprachdatei. Beim Anlegen des Profils (SkuOptions:OnInitialize in SkuZOptions/Core.lua) setzt Sku auf jedem nicht deutschen Client den Text der Client-Sprache ein. Der Pfad des Kampfklangs zeigt dabei auf das installierte Sprachpaket. Vorhandene Einstellungen werden wie bisher nie angefasst.

### Behoben: Ansagen nur auf Deutsch
Was: Diese Ansagen und Chat-Meldungen kamen auch auf einem englischen Client auf Deutsch:
- Sku Datenbank Fehler (SkuDeferredData.lua, SkuDB/ChunkLoader.lua)
- Keine Beacon-Sounds gefunden (SkuCore/companionPacks.lua)
- Aktive Suchen abfragen: "Aktiv", "unbekannt", "Keine Suche aktiv" (SkuCore/minimapScanner.lua)
- Chat verdecken: "Chat sichtbar", "Chat verdeckt" (SkuZOptions/Core.lua)
- Dungeonbrowser: "kein aktiver Eintrag" (SkuCore/dungeonBrowser.lua)
- Navigationsaufgaben: "hoch von", "neigen auf" (SkuNav/specialNavigationTasks.lua)
Wie: Die Texte laufen jetzt über Sku.deEn mit deutschem, englischem und französischem Text.

### Behoben: Erkennung von Spieltexten
Was: Der Knopf "Ignorieren" im Spiel-Popup wurde nur auf einem deutschen Client automatisch geklickt. Der Gebietsname "Höhle der Nebel" (vor den Höhlen des Wehklagens) hatte in der englischen Sprachdatei noch den deutschen Text, die Gebietserkennung griff dort auf Englisch nicht.
Wie: SkuCore/Core.lua vergleicht den Knopftext zusätzlich mit "Ignore" und mit dem Text, den das Spiel selbst dafür verwendet (IGNORE_DIALOG). In locales/enUS.lua steht jetzt der englische Gebietsname "Cavern of Mists".

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.36.zip: mit den Korrekturen.
- Sku-Ever-Installer.exe, installer-version.txt: Installer 1.5.
- SkuAudioData_en.zip: neu, im Release v0.26.
- SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.36.

### Hinweis zum Stand
- Mit einer Codeprüfung aller Texte gefunden. Im Spiel mit englischem Client noch nicht getestet, ebenso wenig der Installer 1.5 mit englischem Paket und bei laufendem Spiel.
- Testbefehle für Entwickler (/skudebug, /skuspec, Datenbankwerkzeuge, Wegpack-Diagnose) sprechen weiter nur Deutsch.

## Sku-Ever 0.36 (16.11.2026)

### Kurzfassung
- Die neuen Forever-Gebiete Zephras, Hyjal, Shen'dralas und Riverglades laufen jetzt komplett über die Engine, so wie bei WowVision (Engine 15 bis 17). Die vier Wegpakete dafür gibt es nicht mehr.
- Dalaran (der alte Krater im Alteracgebirge) läuft ebenfalls über die Engine und ist mit dem Hügelland verbunden (Engine 17.1). Das Wegpaket Dalaran ist entfernt.
- Mehrstöckige Orte: Die Engine merkt sich die Ebene der laufenden Route, fragt nur wenn nötig nach der Ebene und bietet Ziele ohne festen Knoten pro Ebene an ("Name, Ebene 2 von 3").
- Das Questbuch baut seine Routenlisten nicht mehr mit mehreren Sekunden Hänger auf.
- Namen mit Wortteilen wie "nan" bringen die Sprachausgabe nicht mehr zum Abbruch.
- Installer 1.4: installiert die vier neuen Engine-Ordner mit.

### Neu: Neue Gebiete komplett über die Engine
Was: In Zephras, Hyjal, Shen'dralas und Riverglades hat Sku keine eigenen Wege. Dort stehen jetzt alle Ziele aus den WowVision-Daten in F9, Shift-F10 und im Questbuch, ohne dass Ziele wegen eines nahen Sku-Wegpunkts versteckt werden. Die Routen laufen über dieselben Daten wie bei WowVision.
Wie: Vier neue Engine-Addons (SkuEngineZE, SkuEngineHY, SkuEngineSD, SkuEngineRG) mit dem Merkmal wv in Engine_Index.lua (SkuEngineGroups). In SkuNav/EngineRoute.lua entfällt für solche Gruppen der 30-Yard-Test gegen Sku-Wegpunkte; die Spawn-Wegpunkte des Datenpakets zählen dort nicht als Ziele. Die Wegpakete NavPack_ZephrasIsle, NavPack_MountHyjal, NavPack_Shendralas und NavPack_Riverglades sind aus SkuPacks entfernt (sonst gäbe es jedes Ziel doppelt).

### Neu: Ebenen wie bei WowVision
Was: Der Client meldet keine Spielerhöhe. Die Engine nimmt jetzt wie WowVision erst die Ebene der laufenden Route (der Routenpunkt, der dir am nächsten ist), dann die zuletzt bekannte Höhe, und fragt erst dann nach der Ebene. Ziele ohne festen Knoten auf mehreren Ebenen stehen pro Ebene in der Liste ("Name, Ebene n von N"). Die Route endet auf der gewählten Ebene.
Wie: SkuNav/EngineRoute.lua (RouteHeightAt, PlayerHeight, tExpandTargetFloors); gilt nur in den Gebieten mit Merkmal wv.

### Neu: Dalaran über die Engine (Engine 17.1)
Was: Der Dalaran-Krater gehört zur Gruppe NB (Hillsbrad, Alterac, Arathi, Hinterland), seine Wege sind mit dem Hügelland verbunden. Innerhalb eines Kastens um Dalaran gilt dasselbe Verhalten wie in den neuen Gebieten, im Rest der Gruppe bleibt alles wie bisher. Offline geprüft: 634 von 640 Zielen sind vom Hügelland aus erreichbar (sechs Ziele liegen an Stellen ohne begehbaren Boden), und von jedem begehbaren Punkt in Dalaran gibt es eine Route ins Hügelland.
Wie: Engine_Index.lua: die Gruppe NB hat ein Feld wvbox. SkuNav/EngineRoute.lua (tWvAt) entscheidet pro Punkt, ob WV-Verhalten gilt; die Suche geht über alle Gruppen, weil sich die Zonenkästen überlappen. SkuNav/Options.lua: F9 blendet im WV-Bereich die Spawn-Wegpunkte des Datenpakets aus. NavPack_Dalaran ist entfernt.

### Verbessert: Questbuch, Routenlisten
Was: Der Aufbau der Routenlisten im Questbuch brauchte in großen Gebieten mehrere Sekunden.
Wie: SkuQuest/Options.lua (BuildSortedUniqueRouteWps) prüft doppelte Einträge mit einer Nachschlagetabelle statt die ganze Liste für jeden Eintrag zu durchsuchen.

### Behoben: Sprachausgabe bei "nan"
Was: Ein Namensteil wie "nan" (zum Beispiel in "Der Verzicht der Shal'nan") wurde als Zahl behandelt und brachte die Sprachausgabe zum Abbruch; der Name wurde nicht vorgelesen.
Wie: Libs/SkuVoice-1.0 (TokenizeNumberToAudio) spricht Zahlenwerte wie nan oder inf als normalen Text.

### Engine-Nummer
Engine 17.1. Die Nummer zählt jetzt in Schritten von 0,1.

### Downloads
- Sku-Ever-Spielordner.zip: Sku, SkuPacks und alle SkuEngine-Ordner (jetzt mit ZE, HY, SD, RG).
- Sku-Ever-0.36.zip, SkuPacks.zip und je ein Zip pro SkuEngine-Ordner: dieselben Teile einzeln, werden vom Installer benutzt.
- Installer 1.4: installiert auch die vier neuen Engine-Ordner. Ältere Installer aktualisieren sich selbst. Wer von Hand installiert, kopiert die neuen SkuEngine-Ordner mit und löscht die alten Wegpakete NavPack_Dalaran, NavPack_MountHyjal, NavPack_Riverglades, NavPack_Shendralas und NavPack_ZephrasIsle aus dem Ordner SkuPacks.
- Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26.

### Hinweis zum Stand
Die Engine-Routen in den neuen Gebieten und in Dalaran sind offline mit Zufallsrouten geprüft; im Spiel sind sie noch nicht vollständig getestet (Ebenenfrage in Zephras, Dalaran mit Ein- und Ausgang). Der Fix am Questbuch ist im Spiel bestätigt.

## Sku-Ever 0.35 (15.11.2026)

### Kurzfassung
- Keine Fehlermeldung mehr bei Rufen und Emotes von NSCs im Chat, zum Beispiel in der Tiefenbahn.
- Fokus setzen auf ein Ziel mit geschütztem Namen bricht nicht mehr mit einem Fehler ab, Sku sagt stattdessen "Name geschützt, Fokus nicht möglich".
- Setzt du den Spiel-Fokus auf ein Ziel mit geschütztem Namen, liest Sku den Namen über die Spielstimme vor.

### Behoben: Fehler im Chat bei Rufen und Emotes von NSCs
Was: Nach Rufen, Sprüchen und Emotes von NSCs (in der ersten Instanz und in der Tiefenbahn beobachtet) kam immer wieder die Fehlermeldung "HistoryKeeper.lua:9: attempted to index a table that cannot be accessed while tainted (execution tainted by 'Sku')", an einem Abend 33 Mal. Die Chat-Ansage selbst lief weiter.
Wie: Sku liest die Chat-Nachrichten selbst (SkuChat/Core.lua) und holt für jede eine Verlaufsnummer vom Chatverlauf des Spiels (ChatHistory_GetAccessID). Bei NSC-Rufen kann der Absender seit dem 13.11.2026 ein geheimer Wert sein. Das Spiel legt ihn in seiner eigenen Verlaufsliste ab, und ab dann ist diese ganze Liste für Addons gesperrt: jeder weitere Zugriff von Sku bricht ab. Die bisherige Prüfung in SkuChat_SafeAccessID sah nur nach, ob die Werte der einzelnen Nachricht geheim sind, nicht ob die Liste gesperrt ist. Jetzt läuft der Zugriff unter pcall. Verweigert ihn das Spiel, bekommt die Nachricht keine Verlaufsnummer. Die Nummer dient nur der Gruppierung im Chatverlauf, die Nachricht wird ganz normal angezeigt und angesagt.

### Behoben: Fokus setzen auf ein Ziel mit geschütztem Namen
Was: Die Tasten zum Setzen von Fokus 1 bis 8 brachen bei manchen Zielen mit dem Fehler "skuFocus.lua:208: attempt to compare local 'aFocusTargetName' (a secret string value)" ab. Jetzt sagt Sku "Name geschützt, Fokus nicht möglich".
Wie: Sku-Fokus baut aus dem Namen des Ziels ein Anvisier-Makro ("/tar Name", SkuFocus:SetFocusUnitName in SkuCore/skuFocus.lua). Auf WoW: Forever kann UnitName("target") einen geheimen Namen liefern. Den darf ein Addon weder vergleichen noch in einen Text einsetzen, deshalb lässt sich das Makro für solche Ziele nicht bauen. SetFocusUnitName prüft den Namen jetzt zuerst mit Sku.IsSecret und sagt in dem Fall die Meldung an, statt abzubrechen.

### Geändert: Ansage beim Spiel-Fokus
Was: Setzt du den Fokus des Spiels selbst (Fokus-Taste des Spiels, /focus) auf ein Ziel mit geschütztem Namen, sagt Sku "Fokus festgelegt auf" und den Namen.
Wie: Die Ansage (announceGameFocus in SkuCore/skuFocus.lua) setzte den Namen mit dem Ansagetext zusammen, das hätte bei einem geheimen Namen denselben Fehler ausgelöst. Ein geheimer Name geht jetzt über SkuVoice:SpeakSecretText an die Sprachausgabe des Spiels, ein lesbarer Name wie bisher über die normale Ansage.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.35.zip: mit den beiden Korrekturen. Alle anderen Pakete (SkuPacks, die 16 SkuEngine-Gruppen) und der Installer sind unverändert gegenüber 0.34.

### Hinweis zum Stand
- Getestet im Spiel (auf 0.32): Nach dem Reload keine Fehlermeldungen mehr.
- Noch nicht gezielt getestet: die Fokus-Ansage bei einem Ziel mit geschütztem Namen.

## Sku-Ever 0.34 (15.11.2026)

### Kurzfassung
- Das Questbuch baut seine Routenlisten schneller auf: Der Routen-Scan (etwa 60 ms) und die Engine-Einstiegspunkte (etwa 65 ms) werden nicht mehr bei jedem Schritt durch das Questmenü neu berechnet.
- Die Aktualisierung der Quest-Marker läuft in Salven (3 bis 9 Aufrufe pro Sekunde) nur noch einmal pro Sekunde, das beseitigt kurzes Ruckeln.
- Engine 14 (kleiner Unterbau für Sonderziele, ohne sichtbare Änderung).

### Verbessert: Questbuch, Routenliste
Was: Beim Durchgehen eines Questziels (Annahme, Ziel, Abgabe) wurde bei jedem Schritt derselbe Routen-Scan in der Umgebung (etwa 62 ms, vier Mal hintereinander) und die Berechnung der Engine-Einstiegspunkte (etwa 65 ms) wiederholt, obwohl der Spieler stillstand.
Wie: SkuQuest/Options.lua (CreateRtWpSubmenu) merkt sich das Ergebnis des Scans 10 Sekunden, solange Position und Reichweite gleich bleiben. SkuNav/EngineRoute.lua (Engine:EntryPoints) merkt sich die Einstiegspunkte ebenso 10 Sekunden pro Position. Gemessen mit einer temporären Zeitmessung, die nicht im Release ist.

### Verbessert: Quest-Marker ruckeln nicht mehr
Was: Quest-Ereignisse kommen in Salven; jeder Aufruf der Marker-Aktualisierung kostete etwa 11 ms, bis zu neun Mal in einer Sekunde.
Wie: SkuQuest/Core.lua (UpdateZoneAvailableQuestList): Ein Aufruf innerhalb einer Sekunde nach dem letzten wird nicht sofort ausgeführt, sondern es folgt EIN Nachlauf nach der Salve. Ein erzwungener Aufruf (Einstellung geändert) läuft sofort.

### Engine-Nummer
Engine 14. In SkuNav/EngineRoute.lua gibt es neu eine (leere) Liste für Sonderziele mit Höhenangabe; ein Test mit einem Ziel in Sturmwind wurde wieder entfernt. Alle SkuEngineXX-Addons und SkuPacks tragen die neue Revision.

## Sku-Ever 0.33 (15.11.2026)

### Kurzfassung
- Mehrstöckige NPCs (zum Beispiel die Verzauberkunst-Lehrerin im Turm von Azora) stehen in den Routenlisten jetzt zusätzlich als Engine-Ziel, auch wenn Sku einen Wegpunkt dafür hat. Der Engine-Weg endet auf der Etage des NPCs (Engine 12).
- Das Datenpaket (Quests, NPCs, Objekte) ist mit QuestieDB 1.1.1 neu gebaut: 1649 Quests und 3261 NPCs, dazu Quest-Korrekturen aus der neuen Datenbank.
- Neue Einstellung: Abstand der automatischen Pet-Gesundheitsansage im Kampf, wählbar 5, 10, 15 oder 20 Sekunden (Standard 10).

### Neu: Mehrstöckige NPCs als Engine-Ziel
Was: Skus Wegpunkte haben keine Höhe, ein Sku-Weg zu einem NPC in einem mehrstöckigen Gebäude kann auf der falschen Etage enden. Die Engine kennt die Etage des NPCs. Bisher blendete sie ihr Ziel aus, sobald Sku einen Wegpunkt in der Nähe hatte.
Wie: SkuNav/EngineRoute.lua (tMultiFloor, NON_NPC_KINDS): Lehrer, Questgeber, Händler und ähnliche NPCs an Stellen mit mehreren Etagen werden in der Zielliste (Umschalt-F10) zusätzlich als Engine-Eintrag gezeigt. Skus eigene Einträge bleiben unverändert; die Einstiegspunkte ändern sich nicht. Folge: solche NPCs stehen zweimal in der Liste (Sku und Engine).

### Verbessert: Datenpaket mit QuestieDB 1.1.1
Was: Aktualisierte Quest-, NPC-, Objekt- und Gegenstandsdaten, Quest-XP und Übersetzungen aus QuestieDB 1.1.1.
Wie: navpack/build_dbpack.py mit der neuen Datenbank neu gebaut, danach die Quest-Korrekturen und das Ausblenden technischer Platzhalter-NPCs wie bisher angewendet. Die Objekt-Nummern blieben stabil (14 neue), die Wegpakete bleiben gültig. SkuPacks/DataPack_ForeverQuests.lua.

### Neu: Abstand der Pet-Ansage einstellbar
Was: Einstellungen, Allgemein: "Pet-Gesundheit im Kampf: Abstand der Ansagen" mit 5, 10, 15 oder 20 Sekunden. Gilt ab dem nächsten Kampf. Ein Schwellenwert (nur unter 30 Prozent) ist nicht möglich, weil der Wert auf Forever geheim ist.
Wie: SkuCore/petHealth.lua (tPetHealthInterval) und SkuCore/Options.lua (Einstellung petHealthInterval, Standard 10).

### Engine-Nummer
Engine 12. Alle SkuEngineXX-Addons und SkuPacks tragen die neue Revision.

## Sku-Ever 0.32 (15.11.2026)

### Kurzfassung
- Quest-Ziele im Questbuch (zum Beispiel Questgeber im Turm von Azora) landen jetzt auf der richtigen Ebene: die Engine nimmt das Ziel mit gleichem Namen aus ihrem Katalog, statt irgendeine Ebene am Zielpunkt zu wählen (Engine 10).
- Im Questbuch bietet die Engine ihre Ziele jetzt auch unter den Sku-Einstiegspunkten an, nicht nur unter den Engine-Einstiegspunkten.
- "Route umdrehen" (Strg-Umschalt-Z) funktioniert jetzt auch nach einer Engine-Route (Engine 11).

### Behoben: falsche Ebene bei Quest-Zielen
Was: Ein Ziel aus dem Questbuch hat nur x/y, keine Höhe. Die Engine nahm bisher nur bei fast exaktem Treffer das eigene Ziel; sonst die kürzeste Route zu irgendeiner Ebene am Zielpunkt. In Türmen mit mehreren Ebenen (Turm von Azora) war das oft die falsche.
Wie: SkuNav/EngineRoute.lua (tCatalogTargetFor): exakter Treffer, sonst der nächste Katalogeintrag gleichen Namens innerhalb von 10 Yard. Engine:Route und PrepareFollow reichen dafür den Namen durch.

### Neu: Engine-Ziele auch unter Sku-Einstiegspunkten im Questbuch
Was: Wer im Questbuch einen Sku-Einstiegspunkt wählte, sah nur das Sku-Ziel. Jetzt steht darunter zusätzlich das Engine-Ziel (bis zu drei nächste Spawns, mit der üblichen Ebenenfrage).
Wie: SkuNav/Options.lua (AddEngineLeavesForWpNames) und zwei Aufrufe in SkuQuest/Options.lua bei "Route" und "Closest route".

### Behoben: Route umdrehen nach Engine-Route
Was: Nach einer Engine-Route tat Strg-Umschalt-Z nichts, weil Skus Rückweg auf bereits gelöschte, vorübergehende Wegpunkte zeigte.
Wie: SkuNav/EngineRoute.lua (tHookReverse, Engine:ReverseFollow): die Engine merkt sich ihre letzte Route und läuft sie ab dem nächsten Punkt rückwärts, wenn Skus Daten ungültig sind. Bei gültigen Daten oder mehr als 40 Yard Abstand gilt Skus eigener Weg.

### Engine-Nummer
Engine 11. Alle SkuEngineXX-Addons und SkuPacks tragen die neue Revision.

## Sku-Ever 0.31 (15.11.2026)

### Kurzfassung
- Die Engine-Routen (die Wegfindung für Ziele, die Sku nicht erreicht) gibt es jetzt in allen Gebieten der Östlichen Königreiche und Kalimdors, die in den Forever-Daten stehen: 16 Gruppen statt bisher 2.
- Nur noch die Gruppe, in der du stehst, wird geladen. Beim Wechsel wird die alte Gruppe wieder aus dem Speicher genommen.
- Weniger Ruckler nach dem Einloggen: die Namensliste der Engine wird im Hintergrund in kleinen Schritten aufgebaut, nicht mehr in einem Block.
- An Zonengrenzen und zwischen den Kontinenten wird die richtige Zone gewählt.
- Installer 1.3: installiert die neuen Engine-Ordner mit.

### Neu: Engine-Routen in allen Gebieten
Was: Die Engine bietet Ziele (Questgeber, Quest-Ziele, Dungeon-Eingänge, Verkehr und mehr) dort an, wo Sku keinen Weg hat. Jetzt in diesen Gruppen: Sturmwind/Elwynn/Westfall/Rotkamm/Dämmerwald, Eisenschmiede/Dun Morogh/Loch Modan/Sumpfland, Darnassus/Teldrassil, Schlingendorntal, Sümpfe des Elends/Verwüstete Lande/Gebirgspass der Totenwinde, Brennende Steppe/Sengende Schlucht/Ödland, Tirisfal/Unterstadt/Silberwald, Hillsbrad/Alterac/Arathihochland/Hinterland, West- und Ostpestland, Durotar/Orgrimmar/Brachland, Eschental/Dunkelküste, Azshara, Teufelswald/Mondlichtung/Winterquell, Mulgore/Donnerfels/Steinkrallen/Desolace, Feralas/Tausend Nadeln/Düstermarschen, Tanaris/Un'Goro/Silithus. Die Pakete Riverglades, Shen'dralas, Hyjal und Zephras sowie Dalaran bleiben eigene Wegpakete.
Wie: Die Gruppen stehen in einer Liste in SkuPacks/Engine_Index.lua (SkuEngineGroups); jede Gruppe ist ein eigenes Addon (SkuEngineXX), das erst geladen wird, wenn du dort stehst. Die Daten sind mit dem neuen Bauskript aus den WowNav-Zonen erzeugt und geprüft (Ziele nur in ihrer Zone, Kräuter und Erz nicht in Städten, Quest-Ziele markiert, Routen-Stichprobe je Gruppe).

### Neu: Speicher nur für die eigene Gruppe
Was: Beim Wechsel in eine andere Gruppe werden die Daten der vorigen aus dem Speicher genommen (nicht im Kampf).
Wie: SkuNav/EngineRoute.lua (tUnloadOtherGroups) entlädt die entpackten Zonen der anderen Gruppen; bei Bedarf werden sie in Sekundenbruchteilen neu entpackt.

### Verbessert: Hänger nach dem Login
Was: Die Namensliste der Sku-Wegpunkte für die Engine brauchte auf dem Spiel mehrere Sekunden am Stück und lief nach dem Login zweimal.
Wie: SkuNav/EngineRoute.lua löst Gruppe und Karte nur noch einmal pro Sammlung auf, die Sammlung läuft in Schritten von etwa 3 Millisekunden pro Bild und bricht bei Wegpunkt-Änderung, Gruppenwechsel oder Kampf ab. Ein einzelner Hänger von gut einer Sekunde bleibt (Skus eigene Wegpunktliste).

### Verbessert: richtige Zone
Was: Die Zonen-Rechtecke überlappen an Grenzen und zwischen Kontinenten (gleiche Weltkoordinaten). Die Engine nimmt jetzt die Zone des Kontinents, auf dem du stehst, und bei Überlappung die, in der der Punkt am tiefsten liegt.
Wie: SkuNav/EngineRoute.lua (tZonesAt, tInGroup); der Kontinent kommt aus dem 4. Wert von UnitPosition, fehlt er, gilt wie bisher nur die Lage.

### Downloads
- Sku-Ever-Spielordner.zip: Sku, SkuPacks und alle SkuEngine-Ordner.
- Sku-Ever-0.31.zip, SkuPacks.zip und je ein Zip pro SkuEngine-Ordner: dieselben Teile einzeln, werden vom Installer benutzt.
- Installer 1.3: installiert alle Engine-Ordner. Ältere Installer aktualisieren sich selbst. Wer von Hand installiert, kopiert die neuen SkuEngine-Ordner mit.
- Sprachausgabe und Beacon-Töne bleiben unverändert bei Version 0.26.

### Hinweis zum Stand
- Im Spiel getestet: Laden und Listen in Elwynn und Teldrassil sowie die Verbesserung nach dem Login.
- Noch nicht im Spiel getestet: die übrigen neuen Gruppen und der Wechsel zwischen den Gruppen (offline geprüft).

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
