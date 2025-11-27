# SCHNITTWERK

Modern salon management system for **SCHNITTWERK by Vanessa Carosella** in St. Gallen, Switzerland.

## Features

- **Online Booking** - Customers can book appointments 24/7
- **Shop** - Sell hair care products online
- **Customer Portal** - View appointments, orders, loyalty points
- **Admin Dashboard** - Full salon management
- **Multi-Salon Ready** - Architecture supports multiple locations

## Tech Stack

- **Frontend**: Next.js 14+, React, TypeScript, Tailwind CSS, shadcn/ui
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **Payments**: Stripe
- **Email**: Resend
- **Hosting**: Vercel

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env.local

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view.

See [docs/dev-setup.md](docs/dev-setup.md) for detailed setup instructions.

## Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run lint` | Run ESLint |
| `npm run format` | Format with Prettier |
| `npm run typecheck` | TypeScript check |

## Documentation

- [Development Setup](docs/dev-setup.md)
- [Architecture](docs/architecture.md)

## License

Proprietary - All rights reserved.
