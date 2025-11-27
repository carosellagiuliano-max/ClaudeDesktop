'use client';

import { useState } from 'react';
import { Tag, X, Loader2, Truck, Info } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Separator } from '@/components/ui/separator';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { useCart } from '@/contexts/cart-context';

// ============================================
// CART SUMMARY COMPONENT
// ============================================

interface CartSummaryProps {
  compact?: boolean;
  showDiscountInput?: boolean;
  showShipping?: boolean;
}

export function CartSummary({
  compact = false,
  showDiscountInput = false,
  showShipping = true,
}: CartSummaryProps) {
  const { cart, applyDiscountCode, removeDiscountCode, isDigitalOnly, formatPrice } = useCart();

  const [discountCode, setDiscountCode] = useState('');
  const [isApplying, setIsApplying] = useState(false);
  const [discountError, setDiscountError] = useState<string | null>(null);

  const { totals, discounts, shippingMethod } = cart;

  const handleApplyDiscount = async () => {
    if (!discountCode.trim()) return;

    setIsApplying(true);
    setDiscountError(null);

    try {
      // TODO: Validate discount code via server action
      // For now, simulate validation
      await new Promise((resolve) => setTimeout(resolve, 500));

      // Mock discount (replace with actual validation)
      if (discountCode.toUpperCase() === 'WELCOME10') {
        applyDiscountCode({
          code: discountCode.toUpperCase(),
          type: 'percentage',
          value: 10,
          amountCents: Math.round(totals.subtotalCents * 0.1),
          description: '10% Willkommensrabatt',
        });
        setDiscountCode('');
      } else {
        setDiscountError('Ungültiger Gutscheincode');
      }
    } catch {
      setDiscountError('Fehler beim Einlösen des Codes');
    } finally {
      setIsApplying(false);
    }
  };

  if (compact) {
    return (
      <div className="space-y-2 py-4">
        {/* Subtotal */}
        <div className="flex justify-between text-sm">
          <span className="text-muted-foreground">Zwischensumme</span>
          <span>{formatPrice(totals.subtotalCents)}</span>
        </div>

        {/* Discounts */}
        {discounts.map((discount) => (
          <div key={discount.code} className="flex justify-between text-sm text-green-600">
            <span className="flex items-center gap-1">
              <Tag className="h-3 w-3" />
              {discount.description}
            </span>
            <span>-{formatPrice(discount.amountCents)}</span>
          </div>
        ))}

        {/* Shipping */}
        {showShipping && !isDigitalOnly && (
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">Versand</span>
            <span>
              {shippingMethod ? formatPrice(shippingMethod.priceCents) : 'Wird berechnet'}
            </span>
          </div>
        )}

        {/* Total */}
        <Separator className="my-2" />
        <div className="flex justify-between font-semibold">
          <span>Gesamt</span>
          <span className="text-lg">{formatPrice(totals.totalCents)}</span>
        </div>

        {/* VAT Info */}
        <p className="text-muted-foreground text-right text-xs">
          inkl. {formatPrice(totals.taxCents)} MwSt.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Discount Code Input */}
      {showDiscountInput && (
        <div className="space-y-2">
          <label className="text-sm font-medium">Gutscheincode</label>
          <div className="flex gap-2">
            <Input
              placeholder="Code eingeben"
              value={discountCode}
              onChange={(e) => {
                setDiscountCode(e.target.value.toUpperCase());
                setDiscountError(null);
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  handleApplyDiscount();
                }
              }}
            />
            <Button onClick={handleApplyDiscount} disabled={!discountCode.trim() || isApplying}>
              {isApplying ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Einlösen'}
            </Button>
          </div>
          {discountError && <p className="text-destructive text-sm">{discountError}</p>}
        </div>
      )}

      {/* Applied Discounts */}
      {discounts.length > 0 && (
        <div className="space-y-2">
          {discounts.map((discount) => (
            <div
              key={discount.code}
              className="flex items-center justify-between rounded-lg bg-green-50 px-3 py-2 dark:bg-green-950"
            >
              <div className="flex items-center gap-2">
                <Tag className="h-4 w-4 text-green-600" />
                <div>
                  <p className="text-sm font-medium text-green-700 dark:text-green-400">
                    {discount.code}
                  </p>
                  <p className="text-xs text-green-600 dark:text-green-500">
                    {discount.description}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-green-600">
                  -{formatPrice(discount.amountCents)}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-6 w-6 text-green-600 hover:text-green-700"
                  onClick={() => removeDiscountCode(discount.code)}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      <Separator />

      {/* Summary Lines */}
      <div className="space-y-3">
        {/* Subtotal */}
        <div className="flex justify-between">
          <span className="text-muted-foreground">Zwischensumme</span>
          <span>{formatPrice(totals.subtotalCents)}</span>
        </div>

        {/* Discount Total */}
        {totals.discountCents > 0 && (
          <div className="flex justify-between text-green-600">
            <span>Rabatt</span>
            <span>-{formatPrice(totals.discountCents)}</span>
          </div>
        )}

        {/* Shipping */}
        {showShipping && !isDigitalOnly && (
          <div className="flex justify-between">
            <span className="text-muted-foreground flex items-center gap-1">
              <Truck className="h-4 w-4" />
              Versand
            </span>
            <span>
              {shippingMethod ? (
                shippingMethod.priceCents === 0 ? (
                  <span className="text-green-600">Kostenlos</span>
                ) : (
                  formatPrice(shippingMethod.priceCents)
                )
              ) : (
                <span className="text-muted-foreground">Wird berechnet</span>
              )}
            </span>
          </div>
        )}

        {/* Digital Only Notice */}
        {isDigitalOnly && (
          <div className="text-muted-foreground flex items-center gap-2 text-sm">
            <Info className="h-4 w-4" />
            <span>Digitale Produkte - kein Versand erforderlich</span>
          </div>
        )}
      </div>

      <Separator />

      {/* Total */}
      <div className="flex items-baseline justify-between">
        <div>
          <span className="text-lg font-semibold">Gesamtbetrag</span>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="ghost" size="icon" className="ml-1 h-5 w-5">
                  <Info className="h-3 w-3" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Enthält {formatPrice(totals.taxCents)} MwSt. (8.1%)</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
        <div className="text-right">
          <span className="text-2xl font-bold">{formatPrice(totals.totalCents)}</span>
          <p className="text-muted-foreground text-xs">inkl. MwSt.</p>
        </div>
      </div>
    </div>
  );
}
