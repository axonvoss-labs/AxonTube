# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · **Français** · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Apprenez les langues du monde plus vite avec l’IA.**

Version 0.5.3 · Préversion macOS · Puce Apple

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md)

Faites de YouTube votre salle de classe pour apprendre les langues. Avec les sous-titres et les traductions automatiques de YouTube, apprenez à partir des vidéos que vous aimez : lisez deux langues côte à côte, réécoutez chaque phrase et conservez les supports qui comptent pour vous.

**24 langues d’interface · Sous-titres multilingues**

24 désigne le nombre de langues proposées pour l’interface. Les langues des sous-titres dépendent des pistes disponibles pour la vidéo choisie ; ce n’est pas une promesse de maîtriser 24 langues.

## Captures d’écran

Les captures proviennent de l’application réelle 0.5.3. La langue de chaque capture est indiquée séparément de celle de ce document.

### Accueil et parcours principal

![Accueil et parcours principal](../assets/interface-en.png)

Les quatre actions de la barre d’outils, les deux sélecteurs de sous-titres visibles, le slogan localisé et l’état désactivé clairement indiqué avant l’ouverture d’une vidéo. — Capture de l’application en anglais

### Un entraînement phrase par phrase

![Un entraînement phrase par phrase](../assets/interface-study.png)

demo.mp4 — Recherche de phrases, accès par clic, phrase précédente / suivante, réécoute, boucle, vitesse de lecture et suivi de la phrase en cours. — Capture de l’application en anglais

### Premier et second sous-titre

![Premier et second sous-titre](../assets/interface-caption-languages.png)

Capture réelle de l’interface en anglais montrant les menus de sous-titres indépendants, réglés par défaut sur l’anglais et le chinois traditionnel. — Capture de l’application en anglais

### Ouvrir un lien YouTube

![Ouvrir un lien YouTube](../assets/interface-youtube-dialog.png)

Capture réelle de la boîte de dialogue de lien dans l’interface en anglais. L’ouverture d’un lien lance la lecture et demande les deux pistes de sous-titres sélectionnées. — Capture de l’application en anglais

## Premiers pas

### 1. Ouvrez YouTube

Collez le lien d’une vidéo. Les sous-titres disponibles sont demandés automatiquement, avec l’anglais en première piste et le chinois traditionnel en seconde. La première récupération peut prendre environ 1 à 2 minutes ; leur disponibilité n’est pas garantie.

### 2. Choisissez et entraînez-vous

Utilisez les deux menus déroulants de sous-titres visibles. Cliquez sur une phrase pour la rejoindre, la réécouter ou activer sa lecture en boucle.

### 3. Enregistrez ou exportez

Enregistrer la vidéo permet de choisir un dossier pour le média accessible et les sous-titres disponibles. Exporter les sous-titres bilingues crée des fichiers Word, TXT ou SRT à partir des sous-titres chargés.

### 4. Adaptez l’application à vos besoins

Modifiez la langue de l’interface, la vitesse de lecture, la taille des sous-titres et le décalage temporel de chaque piste. L’application mémorise les langues choisies pour l’interface et les sous-titres.

## Fonctions disponibles

### Deux pistes de sous-titres indépendantes

Anglais / chinois traditionnel par défaut ; choisissez parmi les originaux et les traductions automatiques disponibles pour la vidéo en cours. Si la seconde piste échoue, les sous-titres déjà obtenus pour la première restent utilisables.

### Un entraînement phrase par phrase

Recherche de phrases, accès par clic, phrase précédente / suivante, réécoute, boucle, vitesse de lecture et suivi de la phrase en cours.

### Vidéo et sous-titres synchronisés

L’enregistrement reste disponible pendant le chargement des sous-titres. Chaque opération crée un nouveau dossier pour la vidéo accessible et, si des sous-titres sont disponibles, y ajoute les pistes SRT horodatées et les fichiers de lecture bilingue. La vidéo peut aussi être enregistrée seule ; le travail incomplet reste dans un dossier .partial.

### Export Word, TXT et SRT

Exportez les sous-titres disponibles en appliquant les décalages temporels. Word et TXT associent les textes selon le chevauchement temporel. Si une seule piste est chargée, son contenu peut également être exporté.

### 24 interfaces localisées

Les menus, les messages d’état et le slogan d’apprentissage changent de langue ensemble. L’arabe et l’hébreu prennent en charge une présentation de droite à gauche ; changer la langue de l’interface ne modifie pas le contenu des sous-titres.

### Lecture locale et commandes explicites

Ouvrez les médias et les sous-titres locaux depuis le menu Fichier. Les actions indisponibles sont grisées et accompagnées d’une explication ; les modes sélectionnés sont mis en évidence et cochés ; l’enregistrement affiche un état occupé.

## Ce qui la rend utile

### Du visionnage à la pratique en quelques étapes

Quatre actions dans la barre d’outils simplifient le parcours principal : YouTube → Enregistrer la vidéo → Sous-titres → Langue. Aucun bouton supplémentaire n’est nécessaire pour récupérer les sous-titres.

### Des supports d’apprentissage à conserver

Les sous-titres horodatés et les fichiers Word / TXT faciles à lire servent à la compréhension orale comme aux révisions ultérieures. Les exports utilisent de nouvelles destinations et préservent les fichiers d’origine.

### Utilisation locale, sans clé d’API d’IA

Les médias locaux et les sous-titres enregistrés fonctionnent hors ligne. YouTube fournit les sous-titres du site et les traductions automatiques ; l’application n’utilise aucune télémétrie, ne téléverse pas les médias locaux et ne nécessite pas de clé d’API d’IA payante.

## Problèmes ouverts et limites

### P0 · Disponibilité des vidéos et sous-titres YouTube

**Vérification du service réel**

La dernière vérification en ligne a été bloquée par la demande de connexion / vérification anti-bot de YouTube. La réussite des téléchargements en ligne n’a pas été établie dans les conditions actuelles. Avant toute publication, il faut valider le fonctionnement sur le réseau prévu et sur un ensemble représentatif de vidéos.

### P1 · Vidéos soumises à des restrictions d’intégration ou de compte

**Restriction de la plateforme**

Certains auteurs ou certaines vidéos interdisent la lecture intégrée. Google SSO n’est pas implémenté dans l’application ; le raccourci vers le navigateur utilise une session distincte pour la connexion et la lecture. Ces restrictions ne peuvent pas être présentées comme résolues.

### P1 · Signature et tests sur davantage de Mac

**Distribution et compatibilité**

Le paquet porte une signature ad hoc, sans notarisation Developer ID. Apple Silicon sous macOS 26.5.2 a été testé ; macOS 27 et les Mac Intel ne l’ont pas été. macOS 14 est une cible de déploiement, pas la preuve que chaque version a été testée.

### P2 · Qualité des téléchargements et fidélité des sous-titres

**Limites de format et de qualité**

L’enregistrement utilise un flux audio/vidéo complet et ne fusionne pas les flux haute résolution séparés. L’import ASS/SSA ne récupère que le texte. Les sous-titres automatiques, les traductions et l’association bilingue fondée sur le temps peuvent comporter des erreurs. La lecture locale dépend des codecs pris en charge. La conversion facultative avec FFmpeg peut omettre les pistes audio supplémentaires, le HDR et les sous-titres intégrés.

### P2 · Historique d’apprentissage et outils d’étude

**Non implémenté**

La restauration de l’historique de lecture, les collections de vocabulaire, les révisions espacées, l’OCR et l’extraction de sous-titres en image ne sont pas implémentés. Les préférences linguistiques enregistrées ne constituent pas une progression d’apprentissage sauvegardée.

### P2 · Relecture linguistique par des locuteurs natifs

**Révision éditoriale**

Les 24 langues d’interface et leurs slogans localisés ont réussi les tests de changement de langue. Cela confirme la couverture et le comportement, mais pas une relecture professionnelle de chaque traduction par des locuteurs natifs.

## Ce qui a été vérifié

Pour 0.5.3 : 105 vérifications du cœur, 138 assertions du modèle, 29 vérifications des sous-titres, 60 de l’enregistrement vidéo et 317 assertions de l’interface native ont réussi. Les 24 langues ont été sélectionnées dans le menu réel ; six langues d’interface et les dispositions compactes en allemand ont été examinées.

La lecture locale, les exports, les transitions d’état et les boîtes de dialogue natives d’enregistrement ont été vérifiés. Les données de test hors ligne et les tests d’enregistrement avec un auxiliaire simulé ne prouvent pas que YouTube autorise actuellement le téléchargement de sous-titres ou de vidéos en ligne. Aucun identifiant utilisateur n’a été importé.

[Compte rendu détaillé des vérifications](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#fr)

L’application est sous licence MIT ; les composants tiers conservent leurs mentions. AxonTube n’est affilié ni à YouTube, ni à Google, ni à Apple.

Date du document : 2026-10-11
