Laag 2 protocol beschrijving

Het DamExchange laag 2 protocol beschrijft de berichten die de twee tegen elkaar spelende damprogramma's onderling kunnen uitwisselen. Aan de eerste positie in een bericht is altijd te zien om wat voor soort bericht het gaat.

De berichten bestaan uit character strings van minimaal 1 tot maximaal 127 tekens uit de ASCII character set in de waarden 1 tot en met 127.

 

De dialoog tussen de twee damprogramma's verloopt als volgt:

De Initiator stuurt een GAMEREQ bericht (met daarin de informatie betreffende de te spelen partij) naar de Volger.
De Volger beantwoordt met een GAMEACC bericht.
Vervolgens worden MOVE berichten (die de gespeelde zetten bevatten) tussen de twee damprogramma's uitgewisseld. Dit gebeurt om de beurt, dus ook bij gedwongen zetten worden MOVE berichten uitgewisseld.
Dit gaat zo door totdat één der spelers in plaats van een MOVE bericht een GAMEEND bericht stuurt.
Dit GAMEEND bericht wordt bevestigd door een GAMEEND bericht terug te sturen.
Voor interactieve partijen (mens tegen computer) bestaat ook de mogelijkheid van terugzetten met behulp van de BACKREQ en BACKACC berichten.
Op elk moment, dus ook tussen partijen in, kunnen zowel de Initiator als de Volger een CHAT bericht sturen.
De Initiator kan desgewenst telkens een volgende partij starten door weer van voren af aan te beginnen (met het zenden van een GAMEREQ bericht dus).

 

Berichten:

GAMEREQ
GAMEACC
MOVE
GAMEEND
CHAT
BACKREQ
BACKACC
DamExchange Home

GAMEREQ bericht

Dit bericht kan uitsluitend door de Initiator worden verstuurd en geeft aan dat een partij wordt gestart.

Layout

1 byte	2 bytes	32 bytes	1 byte	3 bytes	3 bytes	1 byte	1 byte	50 bytes
header	versie	naam Initiator	kleur Volger	denktijd	aantal zetten	beginstand	kleur aan zet	positie
 

header	type bericht, altijd 'R' (hoofdletter)
versie	versie van het DamExchange protocol, altijd '01'
naam Initiator	de naam van het programma dat de message stuurt; de naam moet bestaan uit precies 32 posities; indien de naam korter is dan 32 posities dan aan de rechterkant aanvullen met spaties (geen '\0' character gebruiken); de naam mag niet met een spatie beginnen
kleur Volger	de kleur (wit of zwart) waarmee de Volger gevraagd wordt deze partij te spelen; moet 'W' of 'Z' zijn (in hoofdletters)
denktijd	de tijd in minuten die elke kleur voor de gehele partij heeft, de instelling van de wedstrijdklok dus; moet gespecificeerd worden in 3 posities; met voorloopnullen (character '0') indien het aantal minuten kleiner dan 100 is; indien de denktijd van één der spelers overschreden is mag de partij door de Initiator of Volger beëindigd worden
aantal zetten	het aantal zetten voor de gehele partij; moet gespecificeerd worden in 3 posities; met voorloopnullen indien het aantal zetten kleiner dan 100 is; na bereiken van het aantal zetten mag de partij door de Initiator of Volger beëindigd worden ongeacht of er reeds een duidelijke uitslag van de partij is; het aantal zetten kan ook als '000' gespecificeerd worden, in dat geval zit er geen limiet aan het aantal te spelen zetten
beginstand	'A': indicatie dat wordt gestart met de normale aanvangsstand (met wit aan zet), in dit geval worden de velden kleur aan zet en positie niet meegestuurd
'B': indicatie dat kleur aan zet en positie wel worden meegestuurd en dat die de beginstand voor de te spelen partij aangeven
kleur aan zet	'W' als wit aan zet is in positie
'Z' als zwart aan zet is in positie
positie	50 bytes die voor de bordvelden 1 tot en met 50 aangeven welk stuk op het bordveld staat; de mogelijke stukken zijn:
'e': leeg veld
'w': witte schijf
'z': zwarte schijf
'W': witte dam
'Z': zwarte dam
 

Voorbeeld:
0----0----1----1----2----2----3----3----4----4----5----5----6----6
0----5----0----5----0----5----0----5----0----5----0----5----0----5
R01Tornado voor Windows 4.0        W060065A

Tornado start een partij vanuit de aanvangsstand waarbij hij zelf met zwart speelt. Er wordt gespeeld met 65 zetten in een uur.

 

Verwerking bij ontvangst (door de Volger) van een GAMEREQ bericht

Ontvangst (door de Volger) van een GAMEREQ bericht wordt herkend aan de header (hoofdletter 'R').
De versie moet gecontroleerd worden, indien het hoger is dan '01', dan is sprake van een nieuwere versie van DamExchange en moet een GAMEACC bericht worden teruggestuurd met acceptatie code 1. Een lager nummer dan '01' bestaat niet.
De naam Initiator is ter informatie en kan bijvoorbeeld gebruikt worden bij het opslaan van gespeelde partijen.
Als de kleur Volger 'W' resp. 'Z' is, speelt de Volger met wit resp. zwart.
De denktijd en het aantal zetten worden door de Volger gebruikt bij het bepalen van de rekentijd per zet.
De beginstand indicator geeft aan met welke stand op het bord gestart wordt.
Indien deze 'A' is, wordt gestart met de normale aanvangsstand (waarbij wit dus als eerste aan zet is). De velden kleur aan zet en positie komen in dit geval niet in het GAMEREQ bericht voor.
Indien deze 'B' is, wordt gestart met kleur aan zet in de beginstand die wordt aangegeven door positie.
Na verwerking van het GAMEREQ bericht antwoordt de Volger met een GAMEACC bericht.
Van het veld beginstand in samenhang met het veld kleur Volger hangt af of de Initiator of de Volger als eerste een MOVE bericht verstuurt na het GAMEACC bericht.
DamExchange Home

GAMEACC bericht

Dit bericht kan uitsluitend door de Volger worden verstuurd als antwoord op een GAMEREQ en geeft aan of de Volger het starten van de partij accepteert.

Layout

1 byte	32 bytes	1 byte
header	naam Volger	acceptatie code
 

header	type bericht, altijd 'A' (hoofdletter)
naam Volger	de naam van het programma dat de message stuurt; de naam moet bestaan uit precies 32 posities; indien de naam korter is dan 32 posities dan aan de rechterkant aanvullen met spaties; de naam mag niet met een spatie beginnen
acceptatie code	`0' indien de Volger de partij accepteert,
`1' indien de Volger de partij niet accepteert omdat de protocol versie uit het voorafgaande GAMEREQ bericht afwijkt,
`2' indien de Volger de partij niet kan of wil accepteren (bijvoorbeeld omdat hij geen partijen wil of kan accepteren die langer dan een bepaalde tijd duren, of bijvoorbeeld dat er geen reglementaire zetten mogelijk zijn in de aangeboden aanvangspositie), maar nog wel eventuele volgende partijen wil spelen,
`3' indien de Volger helemaal geen partijen meer wil spelen
 

Voorbeeld
0----0----1----1----2----2----3----3----4----4----5----5----6----6
0----5----0----5----0----5----0----5----0----5----0----5----0----5
ATornado voor Windows 4.0        0

Tornado accepteert de partij.

 

Verwerking bij ontvangst (door de Initiator) van een GAMEACC bericht

Ontvangst (door de Initiator) van een GAMEACC bericht wordt herkend aan de header (hoofdletter 'A').
De naam Volger is ter informatie en kan gebruikt worden bij het opslaan van gespeelde partijen.
Indien de ontvangen acceptatie code `0' is stuurt de Initiator de openingszet met een MOVE bericht indien de Initiator met wit speelt. Indien de Initiator met zwart speelt wacht deze na ontvangst van het GAMEACC bericht op een MOVE of een GAMEEND bericht van de Volger.
Indien de ontvangen acceptatie code `1' is stopt de Initiator met het spelen van partijen. In de toekomst kan deze code worden gebruikt door de Initiator om op een lager versienummer van het DamExchange protocol terug te kunnen vallen.
Indien de ontvangen acceptatie code `2' is stopt de Initiator met de partij die hij wilde spelen, en start hij de volgende partij (door het sturen van een GAMEREQ bericht).
Indien de ontvangen acceptatie code `3' is stopt de Initiator met het spelen van partijen.
DamExchange Home

MOVE bericht

Dit bericht kan zowel door de Initiator als door de Volger worden verstuurd. Het MOVE bericht geeft een zet door aan het andere programma.

Layout

1 byte	4 bytes	2 bytes	2 bytes	2 bytes	variabel
header	tijd	begin veld	eind veld	aantal geslagen	geslagen stukken
header	type bericht, altijd 'M' (hoofdletter)
tijd	de tijd in seconden die het programma heeft gebruikt voor het doen van de zet in 4 posities; indien de tijd kleiner dan 1000 is dan voorloop nullen gebruiken, mogelijke waarden zijn dus `0000' t/m `9999'; deze rubriek is bij deze versie van het DamExchange protocol ter informatie; in een toekomstige versie van het DamExchange protocol kan functionaliteit worden toegevoegd voor het synchroniseren van de wedstrijdklokken van de twee tegen elkaar spelende programma's
begin veld	het begin veld van de zet in twee posities; indien het begin veld kleiner dan 10 is, dan een voorloop `0' (nul) gebruiken, mogelijke waarden zijn dus `01' t/m `50'
eind veld	het eind veld van de zet in twee posities; indien het eind veld kleiner dan 10 is, dan een voorloop `0' (nul) gebruiken, mogelijke waarden zijn dus `01' t/m `50'
aantal geslagen	het aantal geslagen stukken (schijven en dammen) in twee posities; indien het aantal geslagen stukken kleiner dan 10 is, dan een voorloop `0' (nul) gebruiken, mogelijke waarden zijn dus `00' t/m `20'; als het geen slagzet betreft is deze rubriek dus `00'
geslagen stukken	de veldnummers, elk in twee posities, van de geslagen stukken; de volgorde waarin deze veldnummers worden gegeven is niet van belang; indien een veldnummer kleiner dan 10 is, dan een voorloop `0' (nul) gebruiken, mogelijke waarden zijn dus per veldnummer `01' t/m `50'; het aantal bytes is precies tweemaal zo groot als aangegeven bij rubriek aantal geslagen; als het geen slagzet betreft is deze rubriek dus leeg (0 bytes lang)
Bij een slagzet hebben sommige damprogramma's de informatie aantal geslagen en geslagen stukken altijd nodig. Andere programma's hebben die informatie alleen nodig bij een meerslagzet door een dam waarbij meer zetten mogelijk zijn met begin veld en eind veld hetzelfde
 

Voorbeeld
0----0----1----1----2----2----3----3----4----4----5----5----6----6
0----5----0----5----0----5----0----5----0----5----0----5----0----5
M0012061100
M001205250422122320

Het programma geeft de zetten 6 - 11 resp. 5 x 25 (geslagen over 23, 22, 12 en 20) door. In beide voorbeelden heeft het programma 12 seconden over de zet "nagedacht".

 

Verwerking bij ontvangst van een MOVE bericht

Ontvangst (door de Initiator of Volger) van een MOVE bericht wordt herkend aan de header (hoofdletter 'M').
Rubriek tijd kan ter informatie worden gebruikt.
Het programma voert op het bord de zet gegeven door begin veld, eind veld, aantal geslagen en geslagen stukken uit.
Het programma rekent tot hij een tegenzet klaar heeft en stuurt deze met een MOVE bericht naar het andere programma. Ook bij een gedwongen zet moet het MOVE bericht naar het andere programma gestuurd worden.
Indien echter het programma geen tegenzet wil of kan geven, stuurt hij in plaats van een MOVE bericht een GAMEEND bericht naar het andere programma.
DamExchange Home

GAMEEND bericht

Dit bericht kan zowel door de Initiator als de Volger worden verstuurd als deze de partij wil beeindigen. Dit kan als het programma aan zet is en eigenlijk werd geacht een MOVE bericht te sturen, of als antwoord op ontvangst van een GAMEEND bericht. Als een programma niet aan zet is en geen GAMEEND heeft ontvangen, mag het geen GAMEEND sturen om de partij te beeindigen, maar moet het wachten tot het aan zet is.
Een reden om een partij te beeindigen is bijvoorbeeld omdat de ingestelde speeltijd verstreken is, of bijvoorbeeld omdat het aantal ingestelde zetten overschreden zou worden als hij zou doorspelen.

Layout

1 byte	1 byte	1 byte
header	reden	stop code
 

header	type bericht, altijd 'E' (hoofdletter)
reden	'0' indien het damprogramma wil stoppen met de partij zonder dat hij een reden wil of kan geven, `0' mag dus altijd gebruikt worden; optioneel kunnen door het initiele GAMEEND bericht de volgende codes worden gebruikt: `1' (ik geef op), `2' (remise, bijvoorbeeld door zettenherhaling), '3' (ik win)
stop code	'0' indien de huidige partij moet worden beëindigd, maar een volgende partij gestart mag worden; `1' indien het programma helemaal wil stoppen (dus ook geen volgende partij wil spelen)
Voorbeeld
0----0----1----1----2----2----3----3----4----4----5----5----6----6
0----5----0----5----0----5----0----5----0----5----0----5----0----5
E00

Het programma wil stoppen met de huidige partij maar wil wel doorgaan met volgende partijen.

 

Verwerking bij ontvangst van een GAMEEND bericht

Ontvangst (door de Initiator of de Volger) van een GAMEEND bericht wordt herkend aan de header (hoofdletter 'E'). Merk op dat een GAMEEND bericht kan worden ontvangen op elk moment dat een MOVE bericht verwacht wordt of na het zelf sturen van een GAMEEND bericht.
Rubriek reden kan ter informatie gebruikt worden, bijvoorbeeld bij het opslaan van de gespeelde partij op schijf.
Bij ontvangst in plaats van een MOVE bericht:

Indien de Volger dit bericht ontvangt met stop code `0' dan beeindigt hij de huidige partij, slaat hem eventueel op schijf op, en stuurt ter bevestiging een GAMEEND bericht terug. Als de Volger helemaal wil stoppen doet hij dit met stop code 1, anders met stop code 0. In het laatste geval gaat de Volger staan wachten op ontvangst van een GAMEREQ bericht.
Indien de Volger dit bericht ontvangt met stop code `1' dan beeindigt hij de huidige partij, slaat hem eventueel op schijf op, en stuurt ter bevestiging een GAMEEND bericht terug met stop code 1. De Volger stopt met verder verwerken. Het programma kan dus beeindigd worden.
Indien de Initiator dit bericht ontvangt met stop code `0' dan beeindigt hij de huidige partij, slaat hem eventueel op schijf op, en stuurt ter bevestiging een GAMEEND bericht terug. Als de Initiator helemaal wil stoppen doet hij dit met stop code 1, anders met stop code 0. In het laatste geval start de Initiator een nieuwe partij door het zenden van een GAMEREQ bericht.
Indien de Initiator dit bericht ontvangt met stop code `1' dan beeindigt hij de huidige partij, slaat hem eventueel op schijf op, en stuurt ter bevestiging een GAMEEND bericht terug met stop code 1. De Initiator stopt met verder verwerken. Het programma kan dus beeindigd worden.
Bij ontvangst in antwoord op een zelf gestuurd GAMEEND bericht (reden is altijd '0'):

Indien de Volger dit bericht ontvangt met stop code `0' gaat de Volger staan wachten op ontvangst van een GAMEREQ bericht.
Indien de Volger dit bericht ontvangt met stop code `1' stopt de Volger met verder verwerken. Het programma kan dus beeindigd worden.
Indien de Initiator dit bericht ontvangt met stop code `0' start de Initiator een nieuwe partij door het zenden van een GAMEREQ bericht.
Indien de Initiator dit bericht ontvangt met stop code `1' stopt de Initiator met verder verwerken. Het programma kan dus beeindigd worden.
DamExchange Home

