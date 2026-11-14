# Änderungen in Sku-Ever

Neueste Version zuerst. Jede neue Version erhöht die Nummer um 0.1.

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
