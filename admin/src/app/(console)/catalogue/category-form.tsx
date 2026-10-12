import { ActionForm, Submit } from '@/components/action-form';
import { DEVICE_TYPE } from '@/lib/domain/enums';
import { senToInput } from '@/lib/domain/money';
import { saveCategory } from './actions';

export type Category = {
  id: string;
  name: string;
  slug: string;
  description: string;
  icon: string | null;
  device_types: string[];
  diagnosis_fee_sen: number;
  estimated_repair_min_sen: number;
  estimated_repair_max_sen: number;
  default_warranty_days: number;
  requires_specialist: boolean;
  is_active: boolean;
  sort_order: number;
};

export function CategoryForm({ category }: { category?: Category }) {
  return (
    <ActionForm action={saveCategory}>
      {category && <input type="hidden" name="id" value={category.id} />}
      <div className="form-row">
        <label className="field">
          Name
          <input type="text" name="name" required maxLength={80} defaultValue={category?.name} />
        </label>
        <label className="field">
          Slug
          <span className="hint">Stable identifier used by the classifier. Change with care.</span>
          <input type="text" name="slug" required maxLength={60} defaultValue={category?.slug} className="mono" />
        </label>
      </div>
      <label className="field">
        Description
        <span className="hint">Shown to customers.</span>
        <textarea name="description" maxLength={500} defaultValue={category?.description} />
      </label>

      <div className="form-row">
        <label className="field">
          Diagnosis fee (RM)
          <input type="text" inputMode="decimal" name="diagnosis_fee" required defaultValue={senToInput(category?.diagnosis_fee_sen ?? 2000)} />
        </label>
        <label className="field">
          Repair from (RM)
          <input type="text" inputMode="decimal" name="estimate_min" required defaultValue={senToInput(category?.estimated_repair_min_sen ?? 0)} />
        </label>
        <label className="field">
          Repair to (RM)
          <input type="text" inputMode="decimal" name="estimate_max" required defaultValue={senToInput(category?.estimated_repair_max_sen ?? 0)} />
        </label>
        <label className="field">
          Warranty (days)
          <input type="number" name="default_warranty_days" min={0} max={365} required defaultValue={category?.default_warranty_days ?? 7} />
        </label>
      </div>

      <fieldset className="card" style={{ padding: '12px 14px' }}>
        <legend className="small strong" style={{ padding: '0 4px' }}>
          Applies to
        </legend>
        <div className="form-row">
          {Object.entries(DEVICE_TYPE).map(([key, v]) => (
            <label key={key} className="check">
              <input type="checkbox" name="device_types" value={key} defaultChecked={category?.device_types.includes(key)} />
              {v.label}
            </label>
          ))}
        </div>
      </fieldset>

      <div className="form-row">
        <label className="field">
          Icon
          <span className="hint">Material icon name used by the app.</span>
          <input type="text" name="icon" maxLength={60} defaultValue={category?.icon ?? ''} className="mono" />
        </label>
        <label className="field">
          Sort order
          <input type="number" name="sort_order" defaultValue={category?.sort_order ?? 0} />
        </label>
      </div>

      <div className="actions">
        <label className="check">
          <input type="checkbox" name="is_active" defaultChecked={category?.is_active ?? true} /> Offered to customers
        </label>
        <label className="check">
          <input type="checkbox" name="requires_specialist" defaultChecked={category?.requires_specialist} /> Needs a
          specialist
        </label>
      </div>

      <div>
        <Submit>{category ? 'Save changes' : 'Create category'}</Submit>
      </div>
    </ActionForm>
  );
}
