# Parent online feeding payment — server route

The e10 mobile app (from 1.0.32) has a **Pay for feeding** button on the
parent's Feeding screen. It stays hidden until the live server has the route
below, then switches on by itself — no app update needed.

It works exactly like the school-fees payment the server already has
(`POST /api/students/{id}/pay-balance/pay-intents` + `GET /api/payment-intents/{id}`),
but the money is recorded as a **feeding payment** (same as the cashier's
`POST /api/feeding/payments`), not against school-fees bills.

## 1. Start a payment

`POST /api/students/{student_id}/feeding/pay-intents` — guardian of that student only.

Request body:

| field        | type    | required | notes |
|--------------|---------|----------|-------|
| `provider`   | string  | yes      | `mtn_momo`, `telecel_cash` or `airteltigo_money` (same as fees) |
| `payer_phone`| string  | yes      | wallet number |
| `option`     | string  | yes      | `arrears` (unpaid days only), `today`, `days`, `amount` |
| `mode`       | string  | yes      | `arrears_first` or `ahead_only` (same meaning as `feeding/payments`) |
| `days`       | integer | when `option=days` | 1–200 |
| `amount`     | number  | when `option=amount` | > 0 |

Behaviour:
- Work out the amount and what it covers with the **same logic as
  `POST /api/feeding/quote`** (rates, week/month prices, unpaid days, change).
  `arrears` = pay exactly the unpaid days.
- Create a payment intent (same table/provider integration as fees) with
  `purpose = feeding` and the quote stored on it; send the MoMo prompt.
- Reply `201` with the intent, same shape as the fees pay-intent:
  `{ "data": { "id", "status": "pending", "amount", "reference", "covers" } }`.
- An empty body must answer **422** (the app sends `{}` once to check the
  route exists — 404 means "not available yet"). It must never charge.
- Refuse (422) when the child is a boarder, has no feeding rate, or feeding
  isn't set up.

## 2. When the provider confirms (webhook / status check)

In the same place the fees intent is settled:
- If `purpose = feeding`: record a feeding payment exactly as
  `POST /api/feeding/payments` does (days paid ahead, unpaid days cleared,
  change kept, receipt number), with `method = mobile_money`,
  `reference` = the provider reference, and the cashier field empty /
  "Online (parent)".
- Notify the guardian (`feeding_payment_recorded`, like the cashier flow).
- It must appear in `GET /api/students/{id}/feeding/history` payments and in
  the bursar's `GET /api/feeding/payments` and report, so the website
  reflects it too.

## 3. Status

`GET /api/payment-intents/{id}` (existing) must also return, for feeding
intents: `status` (`pending` → `successful`/`failed`), `amount`, `reference`,
`receipt_number`, `covers` and **`feeding_payment_id`** (the recorded feeding
payment, so the app can open `GET /api/feeding-payments/{id}/receipt`).

## Checklist for the server developer
- [ ] Route + controller + validation (guardian-only, own child).
- [ ] Reuse the feeding quote service; reuse the fees MoMo provider client.
- [ ] Settle into a feeding payment (not a bill payment) on success.
- [ ] `payment-intents/{id}` returns `feeding_payment_id` and `covers`.
- [ ] Tests: empty body 422; boarder/no-rate 422; success records feeding
      payment with reference + receipt; failed intent records nothing.
