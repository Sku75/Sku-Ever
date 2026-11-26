# Änderungen in Sku-Ever

Neueste Version zuerst. Jede neue Version erhöht die Nummer um 0.01. Ab 0.29 beginnt jede Version mit einer Kurzfassung; danach steht zu jeder Änderung, was sich ändert und wie es umgesetzt ist.

## Sku-Ever 0.55 (26.11.2026)

### Kurzfassung
- Neu: Im Navigationsmenü schaltet Strg Pfeil runter zwischen Sku Routen und allen Routen um, mit Ansage in Sku-Stimme. Die Wahl bleibt gemerkt.

### Neu: Strg Pfeil runter, Sku Routen oder alle Routen
Was: Strg Pfeil runter in einer Zielliste mit Engine-Einträgen sagt "Sku Routen" oder "alle" und blendet die Engine-Einträge aus oder wieder ein. Die Wahl gilt für jede Liste und bleibt nach Reload erhalten. Pfeil rechts aus einer Liste mit Engine-Einträgen oder in eine solche sagt den Stand, zum Beispiel vom Einstiegspunkt aus. Besteht eine Liste nur aus Engine-Einträgen, kommt "Sku Routen leer" und die Liste bleibt, wie sie ist. Die Ansage nutzt Skus aufgenommene Wörter und läuft gleichzeitig mit dem Listeneintrag; vorher wurde die Ansage "Nur Sku" vom Listeneintrag abgeschnitten.
Wie: SkuZOptions/Core.lua: Die Wahl steht im Profil unter SkuNav.onlySkuRoutes. ToggleOnlySkuView schaltet sie um und gibt die Ansage zurück; neu SkuOptions:OnlySkuAfterRight wendet die Wahl nach Pfeil rechts an und prüft beide Ebenen auf Engine-Einträge (auch ausgeblendete). Der Tastenhandler spricht die Ansage nach dem Listeneintrag über SkuOptions.Voice:OutputString.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.55.zip: mit der Änderung.
- Installer (1.7), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.54.

## Sku-Ever 0.54 (26.11.2026)

### Kurzfassung
- Behoben: Die Gildenbank sagte viele Plätze als leer an, obwohl dort etwas lag, und manche Gegenstände nur als Platznummer und Anzahl ohne Namen.

### Behoben: Gildenbank, leere Plätze und Gegenstände ohne Namen
Was: Im Gildenbankfach werden jetzt die Gegenstände des Fachs angesagt, das offen ist. Jeder belegte Platz nennt den Namen des Gegenstands, auch wenn das Spiel ihn noch nicht geladen hat. Ein geleerter Platz gilt sofort als leer.
Wie: SkuCore/LocalMenu.lua, Build_GuildBankFrame: Das offene Fach kommt von GetCurrentGuildBankTab statt vom Haken der Reiter-Knöpfe, der im Fenster von Forever nicht stimmt; dadurch wurde oft Fach 1 gelesen. Die Platzdaten am Blizzard-Knopf werden bei jedem Aufbau neu angelegt statt weitergeführt. Der Tooltip bekommt vor SetGuildBankItem einen Besitzer; ist er leer, kommt der Name aus dem Gegenstands-Link.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.54.zip: mit der Änderung.
- Installer (1.7), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.53.

## Sku-Ever 0.53 (26.11.2026)

### Kurzfassung
- Neu: Monitor, Ziel Ansage. Was beim Anvisieren gesagt wird, ist wählbar für Spieler, freundliche NPCs, Gegner, Begleiter und Totems, im Kampf und außerhalb, und eigens für die Taste "Ziel ansagen". Blizzards eigene Zielnamen-Ansage schaltet Sku einmal aus.
- Neu: Monitor, Gesundheit und Ressourcen (ganz oben). Blizzards Audiounterstützung nach eigener Gesundheit, Ressourcen, Ziel, Gruppe und Debuffs geordnet, dazu die Gesundheit des Begleiters mit Taste, Automatik und Hungerhinweis. Der Eintrag im Schnellmenü entfällt.
- Behoben: Der Kampfmonitor sagte "Ziel gewonnen" und "Ziel verloren" im Kampf ununterbrochen an.
- Behoben: Zwei Einheiten mit verborgener Kennung galten als dieselbe. Die weiche Zielerfassung und "Ziel des Ziels" arbeiten dadurch jetzt auch in Instanzen.

### Neu: Monitor, Ziel Ansage
Was: Aus "Ziel Optionen" wird "Ziel Ansage" mit dieser Reihenfolge: Auf Standard zurücksetzen; Zielansage im Kampf; Zielansage nicht im Kampf; Ziel auf Abfrage (oben die Taste "Ziel ansagen", früher "Aktuelles hard target ausgeben", darunter Im Kampf und Außerhalb des Kampfes); Weitere Zieloptionen (Ton bei Ziel im Kampf, Sku-Symbole automatisch setzen, Nur Schlachtzugsymbol, Schlachtzugsymbole wiederholen, Generische Namen, Gegnerstatus Kampf). In jedem Zweig gibt es Spieler, Freundliche NPCs, Gegner, Begleiter und Totems mit Schaltern je Angabe: Name, Titel, Realm, Gilde, Stufe, Selten/Elite/Boss, Rasse, Klasse, Geschlecht, Fraktion, Gruppenrolle, PvP, Abwesend, Nicht stören, Beherrscht, Reaktion, Kreaturentyp, Kreaturenfamilie, Quest-Boss, Questziel, Von anderen beansprucht, Passiv, Besitzer, Ziel im Kampf, Tot, je nach Art. Die Standardwerte werden je Profil einmal gesetzt; außerhalb des Kampfes sagt die Taste alles, im Kampf die mittlere Fassung. Ist ein Schlachtzugsymbol lesbar, kommt sein Name, ist es verborgen, nur die Zahl vor dem Namen. Sku-Symbole automatisch setzen ist jetzt standardmäßig an. Generische Namen ("du selbst", "dein Begleiter", "party 2") ist standardmäßig aus. Die Schalter "Freundliche und feindliche Spieler ansagen", "Spieler mit generischen Beschreibungen ansagen", "Im Kampf bei Spielern Reaktion und Stufe nicht ansagen" und "Blizzard Zielname automatisch regeln" entfallen. Die Blizzard-Ansage "Zielname ansagen" sprach in jeder Instanz jedes Ziel an, auch Gruppenmitglieder; Sku schaltet sie einmal je Profil aus und spricht verborgene Namen selbst.
Wie: SkuMob/Options.lua: SkuMob.TA mit Teile-Liste, Standardwerten, gespeicherter Auswahl (profile.SkuMob.targetAnnounce) und Menü. SkuMob/Core.lua: PLAYER_TARGET_CHANGED setzt die Ansage aus den Lesern tTAReaders zusammen; verborgene Teile gehen über SpeakSecretText, sonst Sku-Stimme, wenn alle Wörter aufgenommen sind, sonst Blizzard-Stimme. Die Taste ruft PLAYER_TARGET_CHANGED("QUERY") (SkuZOptions/Core.lua). SkuMob:SwitchOffBlizzardTargetName ersetzt ApplyBlizzardTargetName. SkuCore:RebindSkuKey (SkuCore/Options.lua) für "Taste belegen". Menüeintrag in SkuCore/aq.lua, Startprofil angepasst, Tastenname in den drei Sprachdateien.

### Neu: Monitor, Gesundheit und Ressourcen
Was: Ganz oben im Monitor: Allgemeine Einstellungen (Audiounterstützung an/aus, Stimme, Geschwindigkeit, Lautstärke, Kampfbeginn, Kampfende, Ansage wenn du anvisiert wirst); Eigene Gesundheit Blizzard Monitor (mit Herzschlag bei niedriger Gesundheit); Eigene Ressource (Mana/Wut/Energie) Blizzard Monitor; Zweite Ressource Blizzard Monitor; Ziel Gesundheit Blizzard Monitor; Begleiter Gesundheit (Taste "Gesundheit des Pets ausgeben", automatische Ansage im Kampf und deren Abstand, Tier Hunger ansagen); Gruppen Gesundheit Blizzard Monitor; Eigene Debuffs Blizzard Monitor. "Optionen Audiounterstützung" im Schnellmenü und die beiden Begleiter-Einträge unter Einstellungen, Allgemein entfallen. Der Hungerhinweis war unter Forever bisher nicht erreichbar. Punkte, die der Client nicht anbietet, zeigen "Leer".
Wie: SkuCore/gameOptions.lua: GameOptions:CAAGeneralMenuBuilder und CAASectionMenuBuilder (Abschnitte als Listen der Blizzard-Variablen, je mit den untergeordneten Zeilen) ersetzen AudioAssistMenuBuilder. SkuCore/aq.lua: neuer erster Eintrag in Aq:MonitorMenuBuilder (nur Forever). SkuCore:InjectSkuKeyEntry (SkuCore/Options.lua) für den Tasteneintrag.

### Behoben: Kampfmonitor, Ziel gewonnen und verloren im Dauerton
Was: Mit eingeschaltetem Kampfmonitor kamen im Kampf ununterbrochen "Ziel gewonnen" und "Ziel verloren". Jetzt kommen sie nur bei einem lesbaren Wechsel.
Wie: SkuCore/aqCombat.lua: Derselbe Gegner wird pro Durchlauf über mehrere Einheiten gelesen (Ziel, Ziel des Begleiters, Ziel des Ziels ...), und Forever verbirgt die Bedrohungswerte auf manchen davon. Ein verborgener Wert galt als "tankt nicht" und kippte den gemerkten Zustand bei jedem Lesen. Jetzt gilt er als unbekannt (tThreatHidden): keine Warnung, der letzte bekannte Stand bleibt.

### Behoben: Zwei verborgene Kennungen galten als dieselbe Einheit
Was: Die weiche Zielerfassung blieb in Instanzen oft stumm, freundliche weiche Ziele mit verborgener Kennung wurden ganz übergangen, und "Ziel des Ziels" kam beim Zielwechsel in Instanzen nie.
Wie: Core.lua: Sku.SameGUID (gleich nur, wenn beide Kennungen lesbar sind) und Sku.SameUnit (fragt das Spiel mit UnitIsUnit). SkuMob/Core.lua: weiche Ziele mit Sku.SameUnit gegen das feste Ziel, softfriend mit UnitExists. SkuCore/aqCombat.lua: Ziel des Ziels mit Sku.SameUnit, Elite-Prüfung auf den Gegner; Tode in der Gruppe und Begleiter mit Sku.SameGUID. SkuAuras/Core.lua: Zwischenspeicher der Auren mit Sku.SameGUID.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.53.zip: mit den Änderungen.
- Installer (1.7), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.52.

## Sku-Ever 0.52 (25.11.2026)

### Kurzfassung
- Behoben (Forever): Wer sich im Dungeonbrowser einträgt und eine Einladung mit Rollenwahl bekommt, hörte nur den Ton. Jetzt gibt es dafür ein Sku-Menü "Gruppeneinladung" mit "Annehmen als <Rolle>" und "Ablehnen".
- Berichtigung zu 0.51: Das dort beschriebene Menü "Dungeon-Einladung" gilt einem Fenster, das es auf Forever nicht gibt. Es hat nichts bewirkt.
- Geändert (Forever): Auf Engine-Routen zählt ein Zwischenpunkt erst bei 1 Meter als erreicht. Vorher waren es bei der Einstellung "Auto" bis zu 4 Meter, wodurch Ecken zu früh abgeschnitten wurden. Skus eigene Routen bleiben unverändert.

### Behoben: Gruppeneinladung mit Rollenwahl (Forever)
Was: Eine Einladung, die Rollen mitbringt, zeigt Blizzard in einem eigenen Fenster (LFGInvitePopup) und nicht in der normalen Einladungsabfrage. Sku kannte das Fenster nicht. Jetzt springt das Menü hinein: je möglicher Rolle ein Eintrag "Annehmen als ...", darunter "Ablehnen". Enter auf einer Rolle wählt genau diese Rolle und nimmt an; mehrere Rollen gleichzeitig lassen sich dort nicht wählen. Wird das Menü ohne Antwort geschlossen, lässt sich die Einladung unter "Lokal" wieder öffnen. Nach der Antwort bleibt kein alter Einladungseintrag zurück.
Wie: SkuCore/LocalMenu.lua (Build_LFGInvitePopup), SkuCore/Core.lua (Fensterliste, Namens- und Aufbau-Tabelle), SkuCore/pendingPrompts.lua (offene Einladung). Aus Blizzards Oberflächencode abgeleitet und offline geprüft; mit einer echten Einladung noch nicht getestet.

### Geändert: Erreicht-Reichweite auf Engine-Routen (Forever)
Was: Die Wegpunkte einer Engine-Route liegen an Ecken und Engstellen; die Navigationsdaten sehen dafür meist 0,5 bis 1 Meter vor. Zwischenpunkte zählen jetzt bei 1 Meter, unabhängig von der eingestellten Reichweite. Der letzte Punkt (das Ziel) richtet sich weiter nach der Einstellung. Die Ansagen "nah" und "weit" bleiben auf Engine-Routen stumm.
Wie: SkuNav/Core.lua (IsFollowingEngineRoute, ProcessCheckReachingWp, UpdateStandardWpReachedRange), SkuNav/Options.lua (Merkmal an der Route). Offline geprüft; im Spiel noch nicht getestet.

## Sku-Ever 0.51 (24.11.2026)

### Kurzfassung
- Neu (Forever): Eine Dungeonfinder-Einladung ("Dungeon bereit") erscheint jetzt als Sku-Menü. Vorher war nur der Ton zu hören, das Fenster blieb unsichtbar. Annehmen und Ablehnen gehen direkt aus dem Menü; nach der Antwort zeigt eine Statuszeile, wie viele Spieler bereit sind.
- Behoben (Forever): Das Wildtierausbildungs-Fenster (aus dem Zauberbuch) zeigte unter "noch lernbar" auch schon Gelerntes, und "schon gelernt" war leer. Die beiden Listen sind jetzt getrennt.
- Engine 17.8: Ziele aller 20 Engine-Gruppen neu aus Brösels Navigationsdaten (Stand 23.11., QuestieDB 1.1.5). Mehr Questgeber und Ziele, vor allem in Tanaris, Un'Goro, Silithus, Mount Hyjal, Shen'dralas und Riverglades. Wegenetze und Höhen sind unverändert.
- Datenpaket aktualisiert auf QuestieDB 1.1.6: 1822 Quests, 3482 NPCs, 803 Objekte, 9090 Gegenstände.

### Neu: Dungeonfinder-Einladung (Forever)
Was: Wenn der Dungeonfinder eine Gruppe gefunden hat, öffnet Blizzard ein Bestätigungsfenster ("Dungeon bereit"). Sku kannte dieses Fenster nicht, daher gab es nur den Ton. Jetzt springt das Menü hinein: Dungeonname und Rolle werden angesagt, "Annehmen" und "Ablehnen" lassen sich direkt wählen. Nach der Antwort steht eine Zeile "Warte auf die anderen Spieler, x von y bereit".
Wie: SkuCore/LocalMenu.lua (neuer Aufbau für LFGDungeonReadyPopup), SkuCore/Core.lua (Eintrag in der Fensterliste, Namenstabelle und Aufbau-Tabelle). Im Spiel bestätigt. Die Rollenwahl-Abfrage (LFGRoleCheck) ist noch nicht abgedeckt.

### Behoben: Wildtierausbildung, Listen (Forever)
Was: Das Spiel meldet bereits gelernte Tierfertigkeiten als "lernbar". Dadurch zeigte die Ansicht "noch lernbar" auch Gelerntes, und "schon gelernt" blieb leer. Jetzt entscheidet Sku selbst, was schon bekannt ist, und trennt die beiden Ansichten. Eine leere Liste sagt "Nichts mehr lernbar" bzw. "Noch nichts gelernt". Höhere Ränge, die außerhalb der sichtbaren Fensterzeilen liegen, bleiben schwer erreichbar (Blizzards Scrollen aus Addon-Code sperrt das Lernen).
Wie: SkuCore/trainerForever.lua (Trennung nach bekannt/unbekannt), SkuCore/Core.lua (ApplyTrainerFilters). Im Spiel bestätigt.

### Engine 17.8
Was: Neue Zieldaten für alle Engine-Gruppen (EK, ZW, KD, SV, SS, BS, NA, NB, NC, KR, KA, KF, KM, KT, KS, KZ, ZE, HY, SD, RG) aus Brösels WoW_NavigationData (Stand fcbe940). Wegenetze, Höhen und Engine-Code sind unverändert. Quest-Markierungen sind überall gleich geblieben oder gestiegen; nur in der Brennenden Steppe (3) und bei Teufelswald/Winterquell/Mondlichtung (10) sind einige Ziele nach Änderungen in Questie keine Questziele mehr.
Wie: SkuEngineXX/Engine_Targets_XX.lua, X-EngineRevision 17.8 in den tocs, SkuEngineRevision 17.8 in SkuPacks/Engine_Index.lua. Im Spiel geprüft (Sturmwind/Elwynn und Zephras: Revision 17.8 geladen, Routen gefunden, keine Fehler); die übrigen Gruppen laden erst beim Besuch.

### Datenpaket QuestieDB 1.1.6
Was: Questie hat Quests, NPCs, Objekte und Gegenstände aktualisiert (u. a. Quest-XP, Fraktionen einiger NPCs, Übersetzungen). Das Datenpaket ist neu aus 1.1.6 gebaut (vorher 1.1.4: 1818 Quests, 3478 NPCs, 802 Objekte).
Wie: SkuPacks/DataPack_ForeverQuests.lua. Beim Laden im Spiel bestätigt (3482 Kreaturen, 1822 Quests, keine Fehler).

## Sku-Ever 0.50 (22.11.2026)

### Kurzfassung
- Datenpaket aktualisiert auf QuestieDB 1.1.4 (Questie 12.12.0): 1818 Quests (vorher 1713), 3478 NPCs, 802 Objekte, 9090 Gegenstände. Neue und korrigierte Questgeber, Abgaben und Ziele, aktualisierte Quest-XP und Übersetzungen.
- Behoben (Forever): Fehler "attempt to index field '?' (a nil value)" in SkuNav/Core.lua beim Anlegen temporärer Wegpunkte, zum Beispiel "Einheiten;Route" beim Folgen einer Einheit.

### Datenpaket QuestieDB 1.1.4
Was: Questie hat Quests, NPCs, Objekte und Gegenstände aktualisiert. Das Datenpaket ist neu aus 1.1.4 gebaut. Gegenüber dem vorigen Stand sind 105 Quests, 504 NPCs, 155 Objekte und 113 Gegenstände neu; 309 NPCs sind entfallen, weil Questie sie aus seiner NPC-Datenbank genommen hat. Es fehlt keine Quest. Die Engine-Zielkataloge bleiben auf Engine 17.7 (QuestieDB 1.1.3).
Wie: SkuPacks/DataPack_ForeverQuests.lua. Beim Laden im Spiel bestätigt (3478 Kreaturen, 1818 Quests, keine Fehler).

### Behoben: Temporäre Wegpunkte (Forever)
Was: Wird ein temporärer Wegpunkt gelöscht, bleibt in der Liste eine Lücke. Beim Neuanlegen wurde der letzte Index mit "#" bestimmt, der bei Lücken nicht verlässlich ist; der Zugriff lief dann ins Leere und warf den Fehler. Auch ein bereits gelöschter Eintrag, den der Cache noch kannte, löste ihn beim Aktualisieren aus. Jetzt wird der neue Index aus dem höchsten vorhandenen berechnet, und ein fehlender Eintrag wird beim Aktualisieren neu angelegt.
Wie: SkuNav/Core.lua, SetWaypoint (Zweig für temporäre Wegpunkte). Die Datei ist syntaktisch geprüft; im Spiel ist der Ablauf noch nicht noch einmal nachgestellt worden.

## Sku-Ever 0.49 (21.11.2026)

### Kurzfassung
- Behoben (Forever): Ein einzeln gewähltes Engine-Ziel (Eintrag mit dem Zusatz "Engine" in der Wegpunktliste) wurde sofort wieder gelöscht. Die Taste zum Drehen zum Wegpunkt tat nichts, der Wegpunkt ließ sich nicht erreichen. Jetzt bleibt der gewählte Wegpunkt bis zum Ankommen oder Abwählen bestehen.

### Behoben: Einzelnes Engine-Ziel (Forever)
Was: Engine-Ziele sind temporäre Wegpunkte. Die Hauptschleife löscht temporäre Wegpunkte alle 0,1 s, solange keine Route verfolgt wird. Ein einzeln gewähltes Ziel war dadurch in derselben Sekunde wieder weg; Drehen zum Wegpunkt und Signalton hatten keine Daten. Beim Folgen einer Route trat das nicht auf. Jetzt behält ClearWaypointsTemporary den gerade gewählten temporären Wegpunkt; er wird erst entfernt, wenn er abgewählt oder ein anderer gewählt wird.
Wie: SkuNav/Core.lua, ClearWaypointsTemporary. Nur unter Forever aktiv. Im Spiel bestätigt (Zephras: Ziel gewählt, Drehung auf 0,0 Grad genau, Ziel erreicht).

## Sku-Ever 0.48 (21.11.2026)

### Kurzfassung
- Neu (Forever): Freundschaftsanfragen per Battle.net: im Chat-Flüstermenü und in der Freundesliste ein Schritt mit Strg+Enter. Im Ziel-Menü gibt es den Eintrag "Freundschaftsanfrage senden" (dort noch nicht im Spiel geprüft).
- Behoben (Forever): Wildtierausbildung. Das Lernen wurde vom Spiel verweigert (Fehler "BuyTrainerService() verboten"). Das Fenster zeigt jetzt nur noch Lernbares; ein Eintrag "Anzeige" schaltet auf "schon gelernt" (nur zum Lesen) um.
- Behoben: Makros auf der Aktionsleiste wurden mit "Makro unbekannt" angesagt, jetzt mit ihrem Namen.
- Behoben (Forever): Hänger beim Öffnen der Routenlisten etwa alle 10 Minuten.
- Engine 17.7: neue Ziele (neue NPCs und Questgeber) in allen Engine-Gruppen, aus QuestieDB 1.1.3 und den WowNav-Daten vom 21.11. In Zephras, Hyjal, Shen'dralas und Riverglades sind jetzt auch die Quest-Markierungen und die Questie-Spawns vollständig, das Datenpaket hat zusätzliche deutsche Namen.

### Neu: Freundschaftsanfrage (Forever)
Was: Auf Forever ist die alte Charakter-Freundesliste aus, ein Freund ist eine Battle.net-Anfrage. Im Chat-Menü einer Zeile sendet der Eintrag "Absender zur Freundesliste hinzufügen" die Anfrage jetzt direkt mit Strg+Enter und sagt "Freundschaftsanfrage gesendet". In der Freundesliste und im Ziel-Menü (Eintrag "Freundschaftsanfrage senden") ist es ein sicheres Makro auf einem zweiten Enter, damit das Öffnen des Menüs nichts versendet. Im Kampf wird nur der Name vorgemerkt.
Wie: SkuChat/Core.lua, SkuCore/friends.lua (FriendRequestMacro), SkuMob/Options.lua. Nur unter Forever aktiv. Im Spiel bestätigt: Chat-Flüstermenü und Freundesliste. Das Ziel-Menü ist noch nicht geprüft.

### Behoben: Wildtierausbildung (Forever)
Was: Beim Wildtierlehrer war das Lernen gesperrt, sobald man im Fenster geblättert hatte. Das Spiel meldet dann ADDON_ACTION_FORBIDDEN für BuyTrainerService, weil die Zeile durch Skus Blättern verändert ist. Jetzt setzt Sku den Filter des Fensters auf "lernbar": Blizzard baut die Liste selbst auf, es wird nicht mehr geblättert. Der Eintrag "Anzeige" am Anfang der Liste schaltet auf "schon gelernt" um (zum Nachlesen, nichts auswählbar). Beim Öffnen steht die Anzeige immer auf "noch lernbar". Die Liste bleibt alphabetisch. Berufs- und Klassenlehrer sind unverändert.
Wie: SkuCore/trainerForever.lua (tAddViewToggle), SkuCore/Core.lua (ApplyTrainerFilters). Nur unter Forever aktiv. Im Spiel bestätigt (Lernen, Umschalten).

### Behoben: Makro-Ansage
Was: Ein Makro auf der Leiste wurde als "Makro unbekannt" angesagt, weil die Nummer aus GetActionInfo auf Forever nicht immer ein Makro-Index ist. Jetzt wird zusätzlich der Name über den Platz der Leiste gelesen. Nur wenn die bisherige Abfrage keinen Namen liefert, deshalb ändert sich auf anderen Clients nichts.
Wie: SkuCore/Options.lua, ButtonContentNameHelper (neuer Parameter aSlot, GetActionText). Im Spiel bestätigt.

### Behoben: Hänger bei Routenlisten
Was: Die Liste der benannten Positionen wurde nach 600 Sekunden verworfen und beim nächsten Aufruf in einem Stück neu gesammelt (gemessen: 1,7 Sekunden Stillstand). Jetzt bleibt sie gültig, bis sich ein Wegpunkt ändert oder die Gruppe wechselt, und wird nach 600 Sekunden nur im Hintergrund in kleinen Häppchen aufgefrischt.
Wie: SkuNav/EngineRoute.lua (WarmNamedPositions, NAMED_REFRESH_S). Nur unter Forever aktiv.

### Engine 17.7 und Datenpaket
Was: Broesels WowNav-Daten (Stand 21.11.) haben neue Zieldaten, die Wegenetze sind unverändert. Alle Engine-Gruppen sind mit QuestieDB 1.1.3 neu gebaut (nur Engine_Targets_*.lua, Wegedaten byte-gleich). Zephras, Hyjal, Shen'dralas und Riverglades hatten bisher kaum Quest-Markierungen und nur wenige Ziele; sie sind jetzt wie Zephras vollständig (Hyjal 162 auf 4041 Ziele, Shen'dralas 154 auf 3763, Riverglades 740 auf 3439, Zephras 8295 auf 8576). Das Datenpaket hat rund 200 geänderte Einträge, vor allem deutsche NPC-Namen und 174 Quest-Korrekturen.
Wie: SkuEngine*/Engine_Targets_*.lua, SkuPacks/Engine_Index.lua (Revision 17.7), SkuPacks/DataPack_ForeverQuests.lua.

### Downloads
- Sku-Ever-0.48.zip, Sku-Ever-Spielordner.zip, SkuPacks.zip und alle 20 SkuEngine-ZIPs sind neu.
- Installer unverändert gegenüber 0.47.

## Sku-Ever 0.47 (20.11.2026)

### Kurzfassung
- Behoben (Forever): An der Grenze zweier Engine-Gruppen (zum Beispiel Brachland und Tausend Nadeln, auch auf Flügen und Schiffen) hingen die Routenlisten und das Questbuch teilweise mehrere Sekunden, und es kamen Fehlermeldungen "script ran too long".
- Passagen jenseits der Reichweite: Die Liste zeigt jetzt bis zu zwölf an die Zone grenzende Passagen (vorher sechs), damit auch weiter entfernte Übergänge wie Eschental nach Brachland erscheinen.
- Datenpaket aus QuestieDB 1.1.3: 56 Quests, 24 NPCs, 4 Objekte und 11 Gegenstände mehr, Korrekturen an vielen weiteren.

### Behoben: Ruckler und Fehler an Gruppengrenzen
Was: Die Engine lädt für die Zone, in der du stehst, die Wegedaten. An Grenzen, wo sich die Zonenrahmen zweier Gruppen überlappen, lud sie Zonen der Nachbargruppe nach, entlud sie aber beim nächsten Aufruf sofort wieder. Das wiederholte sich jede Sekunde und dekodierte die Zonen jedes Mal neu. Folge waren lange Listenaufbauten und BugGrabber-Fehler "script ran too long".
Wie: SkuNav/EngineRoute.lua, tUnloadOtherGroups: Zonen, in deren Rahmen deine Position liegt, bleiben geladen, und eine Gruppe, die in den letzten 90 Sekunden benutzt wurde, wird nicht entladen. Dazu prüft ein kleiner Timer alle 3 Sekunden, ob sich deine Gruppe geändert hat, und wärmt die neue Gruppe im Hintergrund vor (Engine:Preload), auch wenn das Spiel keinen Zonenwechsel meldet. Nur unter Forever aktiv.

### Geändert: mehr Passagen jenseits der Reichweite
Was: Die Liste hatte nur die sechs nächsten angrenzenden Passagen gezeigt, die Passage Eschental nach Brachland fehlte deshalb. Jetzt sind es bis zu zwölf. Es kommen weiter nur Passagen, die an die Zone grenzen, in der du stehst.
Wie: SkuNav/Core.lua, GetAllMetaTargetsFromWp5, tPassagesWanted 12. Nur unter Forever aktiv.

### Datenpaket aus QuestieDB 1.1.3
Was: Das Forever-Datenpaket wurde aus der neuen QuestieDB 1.1.3 neu gebaut: 1713 Quests (+56), 3283 NPCs (+24, 6 entfallen), 647 Objekte (+4), 8977 Gegenstände (+11, 9 entfallen), dazu geänderte Angaben bei 182 Quests, 1252 NPCs, 123 Objekten und 440 Gegenständen.
Wie: navpack/build_dbpack.py und mk_questfill.py, Datei SkuPacks/DataPack_ForeverQuests.lua.

### Downloads
- Sku-Ever-0.47.zip, Sku-Ever-Spielordner.zip und SkuPacks.zip sind neu.
- Installer und alle Engine-Gruppen sind unverändert gegenüber 0.46.

## Sku-Ever 0.46 (20.11.2026)

### Kurzfassung
- Neu (nur Forever): Mit Strg+Pfeil runter blendet man in den Ziellisten (F9/F10 und Shift-F9/F10) alle Engine-Einträge aus und sieht nur Skus eigene Ziele. Ein zweites Strg+Pfeil runter bringt die vorherige Liste zurück. Das funktioniert auch auf einer mit Textfilter gesuchten Liste.
- Neu (nur Forever): In großen Zonen werden Passagen (Zonenübergänge) auch jenseits der Reichweite von 3000 m angezeigt, aber nur die, die an die Zone grenzen, in der man gerade ist.
- Wildtierausbildung (Fenster im Zauberbuch mit den Ausbildungspunkten) ist alphabetisch sortiert.
- Engine 17.6: Sumpfland (Wetlands) und die Anleger von Menethil neu aus den aktuellen Daten von Broesel33.

### Neu: Nur Sku-Ziele mit Strg+Pfeil runter
Was: In den Zielisten blendet Strg+Pfeil runter alle Einträge mit dem Zusatz Engine aus. Zweiter Druck stellt die Liste wieder her. Links, Rechts, Enter oder Tippen heben die Ansicht auf wie einen Textfilter. Die Questlisten sind nicht betroffen.
Wie: SkuZOptions/Core.lua, Funktion ToggleOnlySkuView, nutzt dieselben Listen wie der Textfilter, es wird nichts neu gebaut, nur ausgeblendet. Nur unter Forever aktiv.

### Neu: Passagen jenseits der Reichweite
Was: Ist man in einem Gebiet, das größer ist als die eingestellte Reichweite, fehlten die Passagen am Rand der Zone in der Liste. Jetzt erscheinen bis zu sechs Passagen, die an die aktuelle Zone grenzen, auch wenn sie weiter weg sind. Routen zu ihnen werden ebenfalls berechnet.
Wie: SkuNav/Core.lua, GetAllMetaTargetsFromWp5: Die Wegsuche läuft über die Grenze hinaus weiter, bis genug angrenzende Passagen gefunden sind (Obergrenze der Suche eingebaut), alle anderen Ergebnisse bleiben bei der Reichweite. Nur unter Forever aktiv.

### Geändert: Wildtierausbildung alphabetisch
Was: Die Liste im Fenster der Wildtierausbildung ist nach Namen sortiert.
Wie: SkuCore/trainerForever.lua, Sortierung beim Aufbau der Liste (nur Pet-Ausbildung).

### Engine 17.6: Sumpfland und Menethil
Was: Die Wegedaten und Ziele für Sumpfland wurden neu aufgebaut (Stand von Broesel33 vom 16.11.2026), dazu Nähte zu Loch Modan und Arathi. Anleger und Schiffe in Menethil liegen auf den neuen Anlegern. Die Engine bietet die Ziele Anleger und Am Schiff Auberdine in Menethil nicht mehr an, weil die Route in den Daten entfernt wurde.
Wie: SkuEngineZW (Engine_Data_Wetlands.lua, Engine_Targets_ZW.lua), SkuPacks/Engine_Index.lua, Engine-Revision 17.6.

### Downloads
- Sku-Ever-0.46.zip, Sku-Ever-Spielordner.zip, SkuPacks.zip (nur Engine_Index.lua) und SkuEngineZW.zip sind neu.
- Installer und die übrigen Engine-Gruppen sind unverändert gegenüber 0.45.

## Installer 1.7 und Login-Tool 4.2 (18.11.2026, im Release 0.45 ausgetauscht)

### Kurzfassung
- Das Login-Tool bricht unter Forever nicht mehr mit einer Fehlermeldung ab, wenn auf einem Bildschirm ohne Auswahl eine Pfeiltaste gedrückt wird.
- Charakter erstellen: Nach dem automatischen Erkennen der Spielversion wird die richtige Rasse angeklickt.

### Behoben: Login-Tool, Fehlermeldung "Specifically: t"
Was: Statt "nichts zum Auswählen auf diesem Bildschirm" erschien ein AutoHotkey-Fehlerfenster. Jetzt kommt wieder die Ansage.
Wie: In logintool/v2/includes/forever.ahk (FvMove) verdeckte die Schleifenvariable t die Übersetzungsfunktion T(), AutoHotkey unterscheidet Groß- und Kleinschreibung bei Namen nicht. Die Variable heißt jetzt tg.

### Behoben: Login-Tool, falsche Rasse nach Versionserkennung
Was: Wechselte das Tool nach dem Erkennen der Spielversion etwa von Classic auf TBC, klickte "neuen Charakter erstellen" die Rasse aus der alten Tabelle an (Orc statt Untoter).
Wie: detect.ahk baut nach dem Wechsel das Menü neu (BuildMainMenu).

### Installer 1.7
Was: Der Installer bringt das Login-Tool 4.2 auf bestehende Installationen.
Wie: Config.LoginToolVersion 4.2 (das Login-Tool-Paket im Release login-tool ist ersetzt), Version 1.7 in SkuInstaller.csproj; Sku-Ever-Installer.exe und installer-version.txt im Release 0.45 ausgetauscht.

## Sku-Ever 0.45 (18.11.2026)

### Kurzfassung
- Behoben: In 0.44 fehlten bei den neu gebauten Engine-Gruppen die Quest-Markierungen. Dadurch konnten Quest-Ziele in den Routenlisten und im Questbuch fehlen (Engine-Ziel nicht angeboten), wenn Sku in der Nähe irgendeinen Wegpunkt hatte. Betroffen waren Teldrassil und Dunkelküste, Schlingendorntal, Vorgebirge von Hillsbrad, Brachland, Feralas und Düstermarschen (Engine 17.4).

### Behoben: fehlende Quest-Markierungen in der Engine
Was: In den Zieldateien der Gruppen KD, SV, NB, KR, KA und KT stand bei keinem Ziel mehr die Markierung "ist Ziel einer Quest" (0 statt 1930, 2876, 4924, 7079, 4247 und 4268 Markierungen). Ohne sie blendet die Engine ein Ziel schon aus, wenn Sku in der Nähe irgendeinen Wegpunkt hat, mit ihr nur bei einem Wegpunkt gleichen Namens. Quest-Ziele waren deshalb nicht immer als Engine-Ziel wählbar.
Wie: Die Markierung wurde aus QuestieDB 1.1.2 neu gesetzt (mark_questtargets.py). Die Zahlen stimmen mit dem Stand vor 0.44 überein. Neu ist außerdem eine Pflichtprüfung (markcheck.sh), die vor jedem Einspielen Markierungen und Zeilenzahl der Zieldateien mit dem letzten Stand vergleicht.

### Downloads
- Sku-Ever-Spielordner.zip, SkuPacks.zip (nur Engine_Index.lua) und die Gruppen SkuEngineKD, SV, NB, KR, KA, KT sowie die Revisionsnummer 17.4 in KS und EK; Sku-Ever-0.45.zip nur mit neuer Versionsnummer.
- Installer (1.6) und die übrigen 12 SkuEngine-Gruppen sind unverändert gegenüber 0.44.

## Sku-Ever 0.44 (18.11.2026)

### Kurzfassung
- Schiffe: In Sturmwind kommt man jetzt über die Engine zuverlässig zum Anleger, aufs Schiff und wieder vom Schiff herunter. Dasselbe gilt für Auberdine (Engine 17.3).
- Neue Wegdaten der Engine für Teldrassil, Dunkelküste (Auberdine), Schlingendorntal, Vorgebirge von Hillsbrad, Brachland, Feralas, Düstermarschen und Tanaris, jeweils mit überarbeiteten Schiffsanlegern.
- Das Forever-Datenpaket (Quests, NPCs, Objekte, Gegenstände) ist neu aus QuestieDB 1.1.2 gebaut: 8 Quests mehr, 4 NPCs, 2 Objekte, 1 Gegenstand, dazu korrigierte Spawnpositionen.

### Behoben: Schiff in Sturmwind und Auberdine
Was: Mit den alten Engine-Daten gab es in Sturmwind vom Schiff herunter keine Route ins Gasthaus. Das Ein- und Aussteigen an den Anlegern in Sturmwind und Auberdine klappte nicht zuverlässig. Jetzt gibt es von "Am Schiff" eine Route (39 Punkte), und in Auberdine beginnt die Route am neuen Anleger.
Wie: Die Anlegerdaten stammen aus den aktualisierten WoW-NavigationData von Broesel33 (Stand 16.11.2026, Anleger auf eigenem Pier-Knoten). Neu gebaut wurden die Engine-Gruppen KD, SV, NB, KR, KA, KT, KS sowie in EK die Stadt Sturmwind (Engine_Data_Stormwind.lua, Engine_Targets_EK.lua). Das Wegpaket Dunkelküste (NavPack_DockDarkshore.lua) hat den neuen Anleger bei 6542.3/928.9. SkuPacks/Engine_Index.lua ist passend zusammengeführt; die Zeile für Das Sumpfland (Menethil) und deren Nähte bleiben unverändert, ebenso alle Wegpunkte und Routen von Sku. Die Engine-Software selbst (NavNetwork, EngineRoute.lua) ist unverändert.

### Aktualisiert: Datenpaket aus QuestieDB 1.1.2
Was: Das Datenpaket für Forever enthält jetzt 1657 Quests (vorher 1649), 3265 NPCs, 643 Objekte und 8975 Gegenstände. Rund 60 Quests, 54 Objekte, 154 Gegenstände und viele NPC-Spawnpositionen wurden korrigiert. Es ist nichts weggefallen.
Wie: SkuPacks/DataPack_ForeverQuests.lua wurde neu aus QuestieDB 1.1.2 gebaut (build_dbpack.py, mk_questfill.py) und je Abschnitt auf Syntax geprüft.

### Hinweis
Die Fahrt Sturmwind nach Auberdine ist im Spiel getestet (Route zum Anleger, Einsteigen, Ausstieg in Auberdine, Route zur Hippogryphenmeisterin). Der Rückweg Auberdine nach Sturmwind ist noch nicht im Spiel getestet.

### Downloads
- Sku-Ever-Spielordner.zip, SkuPacks.zip und die Gruppen SkuEngineKD, SV, NB, KR, KA, KT, KS, EK: mit der Änderung. Sku-Ever-0.44.zip: nur die neue Versionsnummer.
- Installer (1.6) und die übrigen 12 SkuEngine-Gruppen sind unverändert gegenüber 0.43.

## Sku-Ever 0.43 (17.11.2026)

### Kurzfassung
- Beim Levelup kommt keine Fehlermeldung mehr, dass Sku die geschützte Funktion SetHiddenGroupBuffs aufrufen wollte.

### Behoben: Fehlermeldung beim Levelup (SetHiddenGroupBuffs)
Was: Beim Levelup, und ebenso bei Talent- oder Spezialisierungswechsel, meldete das Spiel ADDON_ACTION_BLOCKED: Sku habe versucht, SetHiddenGroupBuffs aufzurufen, manchmal zusammen mit SetGroupBuffVisualAlerts. Die Meldung kommt nicht mehr.
Wie: Die Aura-Ende-Ansage (SkuCore/auraEnd.lua) schrieb alle halbe Sekunde eine Diagnosezeile ins Log und fragte dafür den Datenanbieter des Cooldown-Managers (GetOrderedCooldownIDs und die GetCooldownIDs der Anzeigen). Diese Abfrage baut Blizzards Zwischenspeicher neu auf, der dadurch als von Sku geschrieben galt. Beim Levelup liest Blizzards Layoutwechsel diesen Speicher und wird deshalb an SetHiddenGroupBuffs blockiert. Die Diagnosezeile liest jetzt nur noch die Felder der sichtbaren Symbole; die Ansage selbst ist unverändert.

### Downloads
- Sku-Ever-Spielordner.zip, Sku-Ever-0.43.zip: mit der Änderung.
- Installer (1.6), SkuPacks und die 20 SkuEngine-Gruppen sind unverändert gegenüber 0.42.

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
