'use client';

import Image from 'next/image';
import { Minus, Plus, Trash2, Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCart } from '@/contexts/cart-context';
import type { CartItem as CartItemType } from '@/lib/domain/cart/types';

// ============================================
// CART ITEM COMPONENT
// ============================================

interface CartItemProps {
  item: CartItemType;
  compact?: boolean;
}

export function CartItem({ item, compact = false }: CartItemProps) {
  const { updateItem, removeItem, formatPrice } = useCart();

  const handleIncrement = () => {
    updateItem(item.id, item.quantity + 1);
  };

  const handleDecrement = () => {
    if (item.quantity > 1) {
      updateItem(item.id, item.quantity - 1);
    }
  };

  const handleRemove = () => {
    removeItem(item.id);
  };

  if (compact) {
    return (
      <div className="flex items-center gap-3 py-2">
        {/* Image */}
        <div className="bg-muted relative h-12 w-12 flex-shrink-0 overflow-hidden rounded-md">
          {item.imageUrl ? (
            <Image src={item.imageUrl} alt={item.name} fill className="object-cover" />
          ) : item.type === 'voucher' ? (
            <div className="bg-primary/10 flex h-full w-full items-center justify-center">
              <Gift className="text-primary h-5 w-5" />
            </div>
          ) : (
            <div className="flex h-full w-full items-center justify-center">
              <span className="text-muted-foreground text-xs">Bild</span>
            </div>
          )}
        </div>

        {/* Details */}
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium">{item.name}</p>
          <p className="text-muted-foreground text-xs">
            {item.quantity} x {formatPrice(item.unitPriceCents)}
          </p>
        </div>

        {/* Price */}
        <p className="text-sm font-medium">{formatPrice(item.totalPriceCents)}</p>
      </div>
    );
  }

  return (
    <div className="border-border flex gap-4 border-b py-4 last:border-0">
      {/* Image */}
      <div className="bg-muted relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-lg">
        {item.imageUrl ? (
          <Image src={item.imageUrl} alt={item.name} fill className="object-cover" />
        ) : item.type === 'voucher' ? (
          <div className="bg-primary/10 flex h-full w-full items-center justify-center">
            <Gift className="text-primary h-8 w-8" />
          </div>
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <span className="text-muted-foreground text-sm">Bild</span>
          </div>
        )}
      </div>

      {/* Details */}
      <div className="flex flex-1 flex-col">
        <div className="flex justify-between">
          <div>
            <h4 className="font-medium">{item.name}</h4>
            {item.variant && <p className="text-muted-foreground text-sm">{item.variant}</p>}
            {item.type === 'voucher' && item.recipientEmail && (
              <p className="text-muted-foreground mt-1 text-xs">
                Für: {item.recipientName || item.recipientEmail}
              </p>
            )}
          </div>
          <p className="font-semibold">{formatPrice(item.totalPriceCents)}</p>
        </div>

        {/* Quantity Controls */}
        <div className="mt-auto flex items-center justify-between pt-2">
          {item.type === 'voucher' ? (
            // Vouchers can't have quantity changed
            <p className="text-muted-foreground text-sm">
              Wert: {formatPrice(item.unitPriceCents)}
            </p>
          ) : (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="icon"
                className="h-8 w-8"
                onClick={handleDecrement}
                disabled={item.quantity <= 1}
              >
                <Minus className="h-4 w-4" />
              </Button>
              <span className="w-8 text-center text-sm font-medium">{item.quantity}</span>
              <Button variant="outline" size="icon" className="h-8 w-8" onClick={handleIncrement}>
                <Plus className="h-4 w-4" />
              </Button>
            </div>
          )}

          <Button
            variant="ghost"
            size="sm"
            className="text-muted-foreground hover:text-destructive"
            onClick={handleRemove}
          >
            <Trash2 className="mr-1 h-4 w-4" />
            Entfernen
          </Button>
        </div>
      </div>
    </div>
  );
}
