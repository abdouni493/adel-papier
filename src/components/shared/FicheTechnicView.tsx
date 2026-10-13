import { Badge } from '@/components/ui/Badge';
import { formatCurrency } from '@/lib/utils';
import { useLanguage } from '@/hooks/useLanguage';
import type { FicheTechnic } from '@/store/ficheTechnicStore';

/** Fiche technique en lecture : ingrédients, dosages, coûts et gains. */
export function FicheTechnicView({ fiche }: { fiche: FicheTechnic }) {
  const { t } = useLanguage();
  return (
          <div className="space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-gold/5 pb-2">
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant="warning">{fiche.categoryName}</Badge>
                {fiche.sellByUnit && fiche.sellUnit && <Badge variant="info">Unité de vente: {fiche.sellUnit}</Badge>}
                {fiche.usableInProduction && <Badge variant="info" className="bg-caramel/15 text-caramel border-0">Réutilisable en production{fiche.productUnit ? ` (${fiche.productUnit})` : ''}</Badge>}
              </div>
            </div>
            {fiche.imageUrl && (
              <img src={fiche.imageUrl} alt={fiche.name} className="w-full max-h-64 object-contain rounded-xl border border-gold/15 bg-vanilla/30" />
            )}
            {fiche.description && <p className="text-sm text-text-secondary bg-vanilla/20 p-2.5 rounded-xl border border-gold/5 italic">« {fiche.description} »</p>}
            
            <div>
              <h4 className="text-sm font-semibold text-text-secondary mb-2">Ingrédients &amp; Dosage (Fiche Technique)</h4>
              <div className="rounded-xl border border-gold/15 overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-vanilla/60 text-text-secondary"><tr>
                    <th className="text-left px-3 py-2">{t('ingredient')}</th>
                    <th className="text-right px-3 py-2">Dosage Base</th>
                    <th className="text-right px-3 py-2">Coût Unitaire</th>
                    <th className="text-right px-3 py-2">Coût Ligne</th>
                  </tr></thead>
                  <tbody>
                    {fiche.usedProducts.map((u, i) => (
                      <tr key={i} className="border-t border-gold/10">
                        <td className="px-3 py-2 font-medium">
                          <span className="flex items-center gap-1.5">
                            {u.sourceType === 'fiche' && <Badge variant="info" className="bg-pistachio/15 text-pistachio border-0 text-[9px] px-1.5 py-0">Prod</Badge>}
                            {u.productName}
                          </span>
                        </td>
                        <td className="px-3 py-2 text-right tabular">{u.quantityUsed}{u.unit ? ` ${u.unit}` : ''}</td>
                        <td className="px-3 py-2 text-right tabular">{formatCurrency(u.unitCost ?? 0)}</td>
                        <td className="px-3 py-2 text-right tabular text-rose-deep">{formatCurrency(u.lineCost ?? 0)}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="border-t border-gold/15 bg-vanilla/40 font-semibold text-text-primary">
                      <td className="px-3 py-2" colSpan={3}>Coût Total Ingrédients Base</td>
                      <td className="px-3 py-2 text-right tabular text-rose-deep">{formatCurrency(fiche.totalCost)}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <Tile label="Rendement Base" value={`${fiche.outputQuantity}${fiche.sellByUnit && fiche.sellUnit ? ' ' + fiche.sellUnit : ''}`} />
              <Tile label="Prix Vente Unitaire" value={formatCurrency(fiche.unitPrice)} />
              <Tile label="Coût de Revient / Unité" value={formatCurrency(fiche.costPerUnit)} />
              <div className="bg-pistachio/5 border border-pistachio/20 rounded-lg p-2.5 text-center flex flex-col justify-center items-center">
                <p className="text-[10px] text-pistachio font-medium">Gain / Unité</p>
                <p className="text-sm font-bold text-pistachio tabular">{formatCurrency(fiche.gainsPerUnit)}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2 border-t border-gold/5 pt-3">
              <Tile label="Valeur Totale Base" value={formatCurrency(fiche.totalValue)} />
              <div className="bg-pistachio/5 border border-pistachio/20 rounded-lg p-2.5 text-center flex flex-col justify-center items-center">
                <p className="text-[10px] text-pistachio font-medium">Gain Total Base</p>
                <p className="text-base font-bold text-pistachio tabular">{formatCurrency(fiche.totalGains)}</p>
              </div>
            </div>
          </div>
  );
}

function Tile({ label, value }: { label: string; value: string }) {
  return <div className="bg-vanilla/40 rounded-lg p-2.5 text-center"><p className="text-[10px] text-text-muted">{label}</p><p className="text-xs font-bold tabular text-text-primary mt-0.5">{value}</p></div>;
}
