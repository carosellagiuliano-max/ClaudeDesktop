'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  ShoppingBag,
  Truck,
  CreditCard,
  Check,
  ArrowRight,
  ArrowLeft,
  Tag,
  X,
  Loader2,
  Store,
  Wallet,
  Info,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Separator } from '@/components/ui/separator';
import { Textarea } from '@/components/ui/textarea';
import { useCart } from '@/contexts/cart-context';
import { CartItem } from '@/components/shop/cart-item';
import { CartSummary } from '@/components/shop/cart-summary';
import { createOrder } from '@/lib/actions/orders';
import { toast } from 'sonner';
import {
  DEFAULT_SHIPPING_OPTIONS,
  FREE_SHIPPING_THRESHOLD_CENTS,
  type ShippingMethodType,
} from '@/lib/domain/order/types';

// ============================================
// TYPES
// ============================================

type CheckoutStep = 'cart' | 'shipping' | 'payment';
type PaymentMethodType = 'online' | 'pay_at_venue';

interface ShippingFormData {
  name: string;
  email: string;
  phone: string;
  street: string;
  street2: string;
  zip: string;
  city: string;
  country: string;
  notes: string;
}

// ============================================
// CONSTANTS
// ============================================

const STEPS: { id: CheckoutStep; label: string; icon: React.ElementType }[] = [
  { id: 'cart', label: 'Warenkorb', icon: ShoppingBag },
  { id: 'shipping', label: 'Versand', icon: Truck },
  { id: 'payment', label: 'Zahlung', icon: CreditCard },
];

const SALON_ID = process.env.NEXT_PUBLIC_SALON_ID || '';

// ============================================
// CHECKOUT PAGE
// ============================================

export default function CheckoutPage() {
  const router = useRouter();
  const { cart, isEmpty, isDigitalOnly, formatPrice, clear } = useCart();

  const [currentStep, setCurrentStep] = useState<CheckoutStep>('cart');
  const [shippingMethod, setShippingMethod] = useState<ShippingMethodType>('standard');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethodType>('online');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [discountCode, setDiscountCode] = useState('');
  const [appliedDiscount, setAppliedDiscount] = useState<{
    code: string;
    amount: number;
  } | null>(null);

  const [formData, setFormData] = useState<ShippingFormData>({
    name: '',
    email: '',
    phone: '',
    street: '',
    street2: '',
    zip: '',
    city: '',
    country: 'Schweiz',
    notes: '',
  });

  // Get current step index
  const currentStepIndex = STEPS.findIndex((s) => s.id === currentStep);

  // Check if cart qualifies for free shipping
  const freeShipping = cart.totals.subtotalCents >= FREE_SHIPPING_THRESHOLD_CENTS;

  // Get shipping options
  const shippingOptions = isDigitalOnly
    ? [
        {
          type: 'none' as const,
          name: 'Kein Versand',
          priceCents: 0,
          description: 'Digitale Produkte',
        },
      ]
    : DEFAULT_SHIPPING_OPTIONS.map((opt) => ({
        ...opt,
        priceCents: freeShipping && opt.type !== 'pickup' ? 0 : opt.priceCents,
      }));

  // Redirect to shop if cart is empty
  useEffect(() => {
    if (isEmpty && currentStep !== 'cart') {
      router.push('/shop');
    }
  }, [isEmpty, currentStep, router]);

  // Skip shipping step for digital-only orders
  useEffect(() => {
    if (isDigitalOnly && currentStep === 'shipping') {
      setShippingMethod('none');
      setCurrentStep('payment');
    }
  }, [isDigitalOnly, currentStep]);

  // Reset payment method when shipping method changes from pickup
  useEffect(() => {
    if (shippingMethod !== 'pickup' && paymentMethod === 'pay_at_venue') {
      setPaymentMethod('online');
    }
  }, [shippingMethod, paymentMethod]);

  // Handlers
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData((prev) => ({
      ...prev,
      [e.target.name]: e.target.value,
    }));
  };

  const handleNextStep = () => {
    const nextIndex = currentStepIndex + 1;
    if (nextIndex < STEPS.length) {
      setCurrentStep(STEPS[nextIndex].id);
    }
  };

  const handlePrevStep = () => {
    const prevIndex = currentStepIndex - 1;
    if (prevIndex >= 0) {
      setCurrentStep(STEPS[prevIndex].id);
    }
  };

  const validateShippingForm = (): boolean => {
    if (!formData.name.trim()) {
      toast.error('Bitte geben Sie Ihren Namen ein');
      return false;
    }
    if (!formData.email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      toast.error('Bitte geben Sie eine gültige E-Mail-Adresse ein');
      return false;
    }
    if (shippingMethod !== 'pickup' && shippingMethod !== 'none') {
      if (!formData.street.trim()) {
        toast.error('Bitte geben Sie Ihre Strasse ein');
        return false;
      }
      if (!formData.zip.trim()) {
        toast.error('Bitte geben Sie Ihre PLZ ein');
        return false;
      }
      if (!formData.city.trim()) {
        toast.error('Bitte geben Sie Ihren Ort ein');
        return false;
      }
    }
    return true;
  };

  const handleSubmitOrder = async () => {
    if (!validateShippingForm()) return;

    setIsSubmitting(true);

    try {
      const result = await createOrder({
        salonId: SALON_ID,
        customerEmail: formData.email,
        customerName: formData.name,
        customerPhone: formData.phone || undefined,
        shippingMethod: shippingMethod,
        shippingAddress:
          shippingMethod !== 'pickup' && shippingMethod !== 'none'
            ? {
                name: formData.name,
                street: formData.street,
                street2: formData.street2 || undefined,
                zip: formData.zip,
                city: formData.city,
                country: formData.country,
              }
            : undefined,
        customerNotes: formData.notes || undefined,
        source: 'online',
        paymentMethod: paymentMethod === 'pay_at_venue' ? 'pay_at_venue' : 'stripe_card',
        initiatePayment: paymentMethod === 'online',
        items: cart.items.map((item) => ({
          itemType: item.type === 'voucher' ? 'voucher' : 'product',
          productId: item.productId,
          variantId: item.variant,
          itemName: item.name,
          itemDescription: item.description,
          quantity: item.quantity,
          unitPriceCents: item.unitPriceCents,
          voucherType: item.voucherType,
          recipientEmail: item.recipientEmail,
          recipientName: item.recipientName,
          personalMessage: item.personalMessage,
        })),
      });

      if (result.error) {
        toast.error(result.error);
        return;
      }

      if (result.checkoutUrl) {
        // Redirect to Stripe Checkout
        clear();
        window.location.href = result.checkoutUrl;
      } else if (result.order) {
        // Order created without payment (e.g., pay at venue)
        clear();
        router.push(`/checkout/success?order=${result.order.orderNumber}`);
      }
    } catch (error) {
      console.error('Order submission error:', error);
      toast.error('Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleApplyDiscount = async () => {
    if (!discountCode.trim()) return;

    // Mock discount validation (replace with actual API call)
    if (discountCode.toUpperCase() === 'WELCOME10') {
      const discount = Math.round(cart.totals.subtotalCents * 0.1);
      setAppliedDiscount({ code: 'WELCOME10', amount: discount });
      toast.success('Gutscheincode angewendet');
    } else {
      toast.error('Ungültiger Gutscheincode');
    }
    setDiscountCode('');
  };

  // Render empty cart
  if (isEmpty && currentStep === 'cart') {
    return (
      <div className="container max-w-4xl py-12 md:py-20">
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <div className="bg-muted mb-6 flex h-20 w-20 items-center justify-center rounded-full">
            <ShoppingBag className="text-muted-foreground h-10 w-10" />
          </div>
          <h1 className="mb-2 text-2xl font-bold">Ihr Warenkorb ist leer</h1>
          <p className="text-muted-foreground mb-6">
            Entdecken Sie unsere Produkte und Gutscheine.
          </p>
          <Button asChild>
            <Link href="/shop">
              Zum Shop
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="container max-w-6xl py-8 md:py-12">
      {/* Progress Steps */}
      <div className="mb-8">
        <div className="flex items-center justify-center gap-2 md:gap-4">
          {STEPS.map((step, index) => {
            const Icon = step.icon;
            const isActive = step.id === currentStep;
            const isCompleted = index < currentStepIndex;
            const isClickable = isCompleted && !isSubmitting;

            return (
              <div key={step.id} className="flex items-center">
                <button
                  onClick={() => isClickable && setCurrentStep(step.id)}
                  disabled={!isClickable}
                  className={`flex items-center gap-2 rounded-lg px-3 py-2 transition-colors ${
                    isActive
                      ? 'bg-primary text-primary-foreground'
                      : isCompleted
                        ? 'bg-primary/10 text-primary hover:bg-primary/20 cursor-pointer'
                        : 'bg-muted text-muted-foreground'
                  }`}
                >
                  {isCompleted ? <Check className="h-5 w-5" /> : <Icon className="h-5 w-5" />}
                  <span className="hidden font-medium sm:inline">{step.label}</span>
                </button>
                {index < STEPS.length - 1 && (
                  <div
                    className={`mx-2 h-0.5 w-8 md:w-12 ${
                      index < currentStepIndex ? 'bg-primary' : 'bg-border'
                    }`}
                  />
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="grid gap-8 lg:grid-cols-3">
        {/* Main Content */}
        <div className="space-y-6 lg:col-span-2">
          {/* Step 1: Cart Review */}
          {currentStep === 'cart' && (
            <Card>
              <CardHeader>
                <CardTitle>Warenkorb überprüfen</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-0 divide-y">
                  {cart.items.map((item) => (
                    <CartItem key={item.id} item={item} />
                  ))}
                </div>

                {/* Discount Code */}
                <div className="mt-6 border-t pt-6">
                  <Label className="mb-2 block">Gutscheincode</Label>
                  <div className="flex gap-2">
                    <Input
                      placeholder="Code eingeben"
                      value={discountCode}
                      onChange={(e) => setDiscountCode(e.target.value.toUpperCase())}
                    />
                    <Button onClick={handleApplyDiscount} variant="outline">
                      <Tag className="mr-2 h-4 w-4" />
                      Einlösen
                    </Button>
                  </div>
                  {appliedDiscount && (
                    <div className="mt-2 flex items-center justify-between rounded-lg bg-green-50 px-3 py-2 dark:bg-green-950">
                      <span className="text-sm text-green-600">
                        {appliedDiscount.code}: -{formatPrice(appliedDiscount.amount)}
                      </span>
                      <Button variant="ghost" size="sm" onClick={() => setAppliedDiscount(null)}>
                        <X className="h-4 w-4" />
                      </Button>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Step 2: Shipping */}
          {currentStep === 'shipping' && (
            <>
              {/* Contact Info */}
              <Card>
                <CardHeader>
                  <CardTitle>Kontaktdaten</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <div className="space-y-2">
                      <Label htmlFor="name">Name *</Label>
                      <Input
                        id="name"
                        name="name"
                        value={formData.name}
                        onChange={handleInputChange}
                        placeholder="Vor- und Nachname"
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="email">E-Mail *</Label>
                      <Input
                        id="email"
                        name="email"
                        type="email"
                        value={formData.email}
                        onChange={handleInputChange}
                        placeholder="ihre@email.ch"
                        required
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="phone">Telefon (optional)</Label>
                    <Input
                      id="phone"
                      name="phone"
                      type="tel"
                      value={formData.phone}
                      onChange={handleInputChange}
                      placeholder="+41 xx xxx xx xx"
                    />
                  </div>
                </CardContent>
              </Card>

              {/* Shipping Method */}
              <Card>
                <CardHeader>
                  <CardTitle>Versandart</CardTitle>
                </CardHeader>
                <CardContent>
                  <RadioGroup
                    value={shippingMethod}
                    onValueChange={(val) => setShippingMethod(val as ShippingMethodType)}
                  >
                    {shippingOptions.map((option) => (
                      <div
                        key={option.type}
                        className={`flex cursor-pointer items-center justify-between rounded-lg border p-4 transition-colors ${
                          shippingMethod === option.type
                            ? 'border-primary bg-primary/5'
                            : 'hover:bg-muted/50'
                        }`}
                        onClick={() => setShippingMethod(option.type)}
                      >
                        <div className="flex items-center gap-3">
                          <RadioGroupItem value={option.type} id={option.type} />
                          <div>
                            <Label htmlFor={option.type} className="cursor-pointer font-medium">
                              {option.name}
                            </Label>
                            <p className="text-muted-foreground text-sm">{option.description}</p>
                          </div>
                        </div>
                        <span className="font-medium">
                          {option.priceCents === 0 ? (
                            <span className="text-green-600">Kostenlos</span>
                          ) : (
                            formatPrice(option.priceCents)
                          )}
                        </span>
                      </div>
                    ))}
                  </RadioGroup>

                  {freeShipping && (
                    <p className="mt-4 text-sm text-green-600">
                      Kostenloser Versand ab CHF 50 Bestellwert!
                    </p>
                  )}
                </CardContent>
              </Card>

              {/* Shipping Address */}
              {shippingMethod !== 'pickup' && shippingMethod !== 'none' && (
                <Card>
                  <CardHeader>
                    <CardTitle>Lieferadresse</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="space-y-2">
                      <Label htmlFor="street">Strasse und Hausnummer *</Label>
                      <Input
                        id="street"
                        name="street"
                        value={formData.street}
                        onChange={handleInputChange}
                        placeholder="Musterstrasse 123"
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="street2">Adresszusatz (optional)</Label>
                      <Input
                        id="street2"
                        name="street2"
                        value={formData.street2}
                        onChange={handleInputChange}
                        placeholder="c/o, Apartment, etc."
                      />
                    </div>
                    <div className="grid gap-4 sm:grid-cols-2">
                      <div className="space-y-2">
                        <Label htmlFor="zip">PLZ *</Label>
                        <Input
                          id="zip"
                          name="zip"
                          value={formData.zip}
                          onChange={handleInputChange}
                          placeholder="9000"
                          required
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="city">Ort *</Label>
                        <Input
                          id="city"
                          name="city"
                          value={formData.city}
                          onChange={handleInputChange}
                          placeholder="St. Gallen"
                          required
                        />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="country">Land</Label>
                      <Input id="country" name="country" value={formData.country} disabled />
                    </div>
                  </CardContent>
                </Card>
              )}

              {/* Notes */}
              <Card>
                <CardHeader>
                  <CardTitle>Bemerkungen (optional)</CardTitle>
                </CardHeader>
                <CardContent>
                  <Textarea
                    name="notes"
                    value={formData.notes}
                    onChange={handleInputChange}
                    placeholder="Besondere Anweisungen zur Lieferung..."
                    rows={3}
                  />
                </CardContent>
              </Card>
            </>
          )}

          {/* Step 3: Payment */}
          {currentStep === 'payment' && (
            <>
              {/* Payment Method Selection */}
              <Card>
                <CardHeader>
                  <CardTitle>Zahlungsmethode wählen</CardTitle>
                </CardHeader>
                <CardContent>
                  <RadioGroup
                    value={paymentMethod}
                    onValueChange={(val) => setPaymentMethod(val as PaymentMethodType)}
                    className="space-y-3"
                  >
                    {/* Online Payment */}
                    <div
                      className={`flex cursor-pointer items-start justify-between rounded-lg border p-4 transition-colors ${
                        paymentMethod === 'online'
                          ? 'border-primary bg-primary/5'
                          : 'hover:bg-muted/50'
                      }`}
                      onClick={() => setPaymentMethod('online')}
                    >
                      <div className="flex items-start gap-3">
                        <RadioGroupItem value="online" id="online" className="mt-1" />
                        <div>
                          <Label
                            htmlFor="online"
                            className="flex cursor-pointer items-center gap-2 font-medium"
                          >
                            <CreditCard className="h-4 w-4" />
                            Online bezahlen
                          </Label>
                          <p className="text-muted-foreground mt-1 text-sm">
                            Sicher mit Kreditkarte, TWINT oder weiteren Zahlungsmethoden
                          </p>
                          <div className="text-muted-foreground mt-2 flex items-center gap-2 text-xs">
                            <span className="bg-muted rounded px-2 py-0.5">Visa</span>
                            <span className="bg-muted rounded px-2 py-0.5">Mastercard</span>
                            <span className="bg-muted rounded px-2 py-0.5">TWINT</span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Pay at Venue - only for pickup orders */}
                    {shippingMethod === 'pickup' && (
                      <div
                        className={`flex cursor-pointer items-start justify-between rounded-lg border p-4 transition-colors ${
                          paymentMethod === 'pay_at_venue'
                            ? 'border-primary bg-primary/5'
                            : 'hover:bg-muted/50'
                        }`}
                        onClick={() => setPaymentMethod('pay_at_venue')}
                      >
                        <div className="flex items-start gap-3">
                          <RadioGroupItem value="pay_at_venue" id="pay_at_venue" className="mt-1" />
                          <div>
                            <Label
                              htmlFor="pay_at_venue"
                              className="flex cursor-pointer items-center gap-2 font-medium"
                            >
                              <Store className="h-4 w-4" />
                              Im Salon bezahlen
                            </Label>
                            <p className="text-muted-foreground mt-1 text-sm">
                              Bezahlen Sie bequem bei der Abholung im Salon
                            </p>
                            <div className="text-muted-foreground mt-2 flex items-center gap-2 text-xs">
                              <span className="bg-muted rounded px-2 py-0.5">Bar</span>
                              <span className="bg-muted rounded px-2 py-0.5">Karte</span>
                              <span className="bg-muted rounded px-2 py-0.5">TWINT</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    )}
                  </RadioGroup>

                  {/* Info for pay at venue */}
                  {paymentMethod === 'pay_at_venue' && (
                    <div className="mt-4 flex items-start gap-3 rounded-lg bg-blue-50 p-4 dark:bg-blue-950">
                      <Info className="mt-0.5 h-5 w-5 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                      <div className="text-sm text-blue-800 dark:text-blue-200">
                        <p className="mb-1 font-medium">Hinweis zur Abholung</p>
                        <p>
                          Ihre Bestellung wird für Sie reserviert. Bitte holen Sie diese innerhalb
                          von 7 Tagen ab und bezahlen Sie bei Abholung.
                        </p>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Order Summary Card */}
              <Card>
                <CardHeader>
                  <CardTitle>Bestellung bestätigen</CardTitle>
                </CardHeader>
                <CardContent>
                  {/* Order Summary */}
                  <div className="mb-6 space-y-4">
                    <div>
                      <h4 className="mb-2 font-medium">Kontakt</h4>
                      <p className="text-muted-foreground text-sm">{formData.email}</p>
                      <p className="text-muted-foreground text-sm">{formData.name}</p>
                    </div>

                    {shippingMethod !== 'none' && (
                      <div>
                        <h4 className="mb-2 font-medium">Versand</h4>
                        {shippingMethod === 'pickup' ? (
                          <p className="text-muted-foreground text-sm">Abholung im Salon</p>
                        ) : (
                          <p className="text-muted-foreground text-sm">
                            {formData.street}
                            {formData.street2 && `, ${formData.street2}`}
                            <br />
                            {formData.zip} {formData.city}
                          </p>
                        )}
                      </div>
                    )}

                    <div>
                      <h4 className="mb-2 font-medium">Zahlungsmethode</h4>
                      <p className="text-muted-foreground flex items-center gap-2 text-sm">
                        {paymentMethod === 'online' ? (
                          <>
                            <CreditCard className="h-4 w-4" />
                            Online bezahlen
                          </>
                        ) : (
                          <>
                            <Store className="h-4 w-4" />
                            Im Salon bezahlen
                          </>
                        )}
                      </p>
                    </div>
                  </div>

                  <Separator className="my-6" />

                  {/* Items */}
                  <div className="space-y-3">
                    {cart.items.map((item) => (
                      <div key={item.id} className="flex justify-between text-sm">
                        <span>
                          {item.quantity}x {item.name}
                        </span>
                        <span className="font-medium">{formatPrice(item.totalPriceCents)}</span>
                      </div>
                    ))}
                  </div>

                  <Separator className="my-6" />

                  <p className="text-muted-foreground mb-6 text-sm">
                    {paymentMethod === 'online' ? (
                      <>
                        Durch Klicken auf &ldquo;Jetzt bezahlen&rdquo; werden Sie zu unserem
                        sicheren Zahlungsanbieter weitergeleitet.
                      </>
                    ) : (
                      <>
                        Durch Klicken auf &ldquo;Bestellung aufgeben&rdquo; reservieren wir Ihre
                        Bestellung. Sie bezahlen bei Abholung.
                      </>
                    )}
                  </p>
                </CardContent>
              </Card>
            </>
          )}

          {/* Navigation */}
          <div className="flex justify-between">
            {currentStepIndex > 0 ? (
              <Button variant="outline" onClick={handlePrevStep} disabled={isSubmitting}>
                <ArrowLeft className="mr-2 h-4 w-4" />
                Zurück
              </Button>
            ) : (
              <Button variant="outline" asChild>
                <Link href="/shop">
                  <ArrowLeft className="mr-2 h-4 w-4" />
                  Weiter einkaufen
                </Link>
              </Button>
            )}

            {currentStep === 'payment' ? (
              <Button onClick={handleSubmitOrder} disabled={isSubmitting} size="lg">
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Wird verarbeitet...
                  </>
                ) : paymentMethod === 'online' ? (
                  <>
                    Jetzt bezahlen
                    <CreditCard className="ml-2 h-4 w-4" />
                  </>
                ) : (
                  <>
                    Bestellung aufgeben
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </>
                )}
              </Button>
            ) : (
              <Button onClick={handleNextStep}>
                Weiter
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            )}
          </div>
        </div>

        {/* Order Summary Sidebar */}
        <div className="lg:col-span-1">
          <div className="sticky top-24">
            <Card>
              <CardHeader>
                <CardTitle>Bestellübersicht</CardTitle>
              </CardHeader>
              <CardContent>
                <CartSummary compact showShipping={currentStep !== 'cart'} />
              </CardContent>
            </Card>

            {/* Trust Badges */}
            <div className="text-muted-foreground mt-6 text-center text-sm">
              <p className="mb-2">Sichere Zahlung mit</p>
              <div className="flex justify-center gap-4">
                <span>Visa</span>
                <span>Mastercard</span>
                <span>TWINT</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
