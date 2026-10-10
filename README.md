# Papeterie Production — Gestion d'usine de papier

Application web de gestion d'une usine de production de papier : matières premières, achats,
fiches techniques et production, comptoir, point de vente (POS), ventes, commandes et bons de
livraison, clients, fournisseurs, employés, dépenses, caisse, rapports et paramètres.
Interface **rouge & noir**, démarrage en **mode clair** avec bascule **mode sombre**, bilingue
**Français / Arabe (RTL)**, animations Framer Motion.

## Stack

React 18 · TypeScript · Vite · Tailwind CSS · Framer Motion · Zustand · Recharts · Supabase
(Postgres, Auth, Storage, RLS).

## Mise en route

1. **Base de données** — dans Supabase › SQL Editor, exécutez
   [`supabase/papeterie_supabase_full.sql`](supabase/papeterie_supabase_full.sql) (une seule fois ;
   le script peut être relancé sans risque). Il crée :
   - toutes les tables et relations (stock, achats, production, comptoir, ventes, commandes,
     livraisons, paiements, anciennes dettes, acomptes, employés, dépenses, caisse, corbeille) ;
   - les déclencheurs métier (stock, comptoir, caisse, soldes) ;
   - toutes les fonctions RPC appelées par les boutons de l'application ;
   - la sécurité RLS par module et par action (voir / créer / modifier / supprimer / payer) ;
   - les buckets Storage `store-assets`, `product-images` (publics) et `documents` (privé).
   Les sections lisibles séparément sont dans [`supabase/parts/`](supabase/parts/).

   **Base déjà installée ?** Exécutez seulement
   [`supabase/parts/07_livraisons_stock_pret.sql`](supabase/parts/07_livraisons_stock_pret.sql)
   (mise à jour 2026-10 : livraisons, stock prêt, récupérations, factures non comptabilisées,
   images des fiches techniques). Le script peut être relancé sans risque.
2. **Variables** — copiez `.env.example` en `.env` et renseignez la clé anon du projet.
3. **Lancer** :
   ```bash
   npm install
   npm run dev
   ```

## Comptes

- **Premier lancement** : la page de connexion propose « Créer le compte Administrateur ». Le compte
  est créé dans `auth.users` (Supabase Auth) ; le bouton disparaît dès qu'un administrateur existe.
- **Employés** : créés depuis *Employés* par l'administrateur (compte Supabase Auth réel). Chaque
  employé ne voit que les interfaces et les boutons que l'administrateur lui a accordés ; la base
  applique les mêmes règles (RLS + contrôle dans chaque fonction RPC).

## Modèle comptable

- Une **livraison est une vente** : chaque bon de livraison génère une facture (Ventes), avec
  montant versé et reste ; elle apparaît dans la caisse, les rapports et la fiche du client.
- Une **commande n'est pas une dette** ; seul ce qui est livré est dû.
- Un versement client solde d'abord les anciennes dettes puis les factures les plus anciennes ;
  l'excédent devient un **acompte** utilisable ensuite.
- **Ancien achat / ancienne vente** : enregistrés à leur date, sans mouvement de stock ni de caisse.

## Livraisons & stock prêt

- **Stock prêt** d'un produit (fiche technique) = ses productions − ce qui est parti au comptoir −
  ce qui a été livré + ce qui a été récupéré. Le tableau de bord affiche, par produit, le total
  commandé, le total livré, le **reste à livrer** (il baisse à chaque livraison), le stock prêt et ce
  qu'il reste à produire.
- **Livraisons** (menu Commercial) : client → produits → quantités. Le reste commandé du client et
  le stock prêt s'affichent ; une quantité supérieure au stock prêt est **produite automatiquement**
  (production rattachée au bon, matières déduites du stock). Les quantités sont imputées sur les
  commandes du client, la plus ancienne d'abord (un bon par commande servie). La même règle
  s'applique aux livraisons saisies depuis l'écran Commandes.
- **Récupération** d'un bon : la marchandise revient au stock prêt et redevient « à livrer », la
  facture baisse, et l'argent payé en trop est rendu au client (sortie de caisse) ou gardé en
  acompte ; un bon de récupération s'imprime et l'opération figure dans l'historique du client.
- **Factures non comptabilisées** : factures, proformas ou bons de livraison seulement imprimés —
  aucun effet sur le stock, la caisse, la dette des clients ni les rapports.
- **Fiches techniques** : photo du produit, et impression d'une **liste des prix** (produits cochés).

## Pointeuse ZKTeco (K50 Pro) — présences, absences, paie

La pointeuse envoie chaque pointage en temps réel (protocole **ZKTeco PUSH / ADMS** du SDK) à la
passerelle `pointeuse/bridge.mjs`, lancée sur le PC relié à la pointeuse ; celle-ci l'enregistre
dans Supabase. Écran **Pointage** (menu Gestion) : présents du jour, état mensuel, journal,
connexion de la pointeuse, paramètres (horaires, tolérances, jours de repos, retenues).
Chaque employé a un bouton **Pointage** (heure et minute d'entrée / de sortie de chaque jour,
retards, départs anticipés, heures sup., absences) et la **Paie** peut se calculer avec la pointeuse.

1. **SQL** : exécutez [`supabase/parts/10_pointeuse.sql`](supabase/parts/10_pointeuse.sql).
2. **Jeton** : application › Pointage › onglet *Pointeuse* › *Copier* le jeton, puis collez-le dans
   `pointeuse/config.json` (`"token": "…"`). Port par défaut : **8090**.
3. **Pare-feu Windows** (PowerShell administrateur, une seule fois) :
   `New-NetFirewallRule -DisplayName "Pointeuse ZKTeco 8090" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow`
4. **Lancer** : `lancer-pointeuse.bat` (démarre aussi automatiquement à l'ouverture de session ;
   page d'état : http://localhost:8090).
5. **Sur la pointeuse** : Menu › COMM. › Ethernet : IP `192.168.1.201`, passerelle `192.168.1.1` ;
   Menu › COMM. › Paramètres Serveur Cloud (ADMS) : adresse du serveur = IP du PC (`192.168.1.50`),
   port `8090`, HTTPS désactivé, proxy désactivé.
6. **Employés** : Employés › Modifier › *N° pointeuse* (= ID utilisateur sur la pointeuse) ;
   enregistrer l'empreinte sur la pointeuse (Menu › Utilisateurs › Nouvel utilisateur, même ID) ou
   à distance (bouton *Enregistrer l'empreinte à distance*).
