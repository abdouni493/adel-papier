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
