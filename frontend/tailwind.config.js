/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    boxShadow: {
      sm: '0 0 0 1px rgb(46 46 46 / 0.32)',
      DEFAULT: '0 0 0 1px rgb(46 46 46 / 0.36)',
      md: '0 0 0 1px rgb(46 46 46 / 0.4)',
      lg: '0 0 0 1px rgb(46 46 46 / 0.48)',
      xl: '0 0 0 1px rgb(54 54 54 / 0.56)',
      '2xl': '0 0 0 1px rgb(57 57 57 / 0.64)',
      inner: 'inset 0 1px 0 rgb(255 255 255 / 0.04)',
      none: '0 0 #0000',
      glass: '0 0 0 1px rgb(46 46 46 / 0.52)',
      'glass-sm': '0 0 0 1px rgb(46 46 46 / 0.42)',
      glow: '0 0 0 1px rgb(62 207 142 / 0.3)',
      'glow-lg': '0 0 0 1px rgb(62 207 142 / 0.42)',
      card: '0 0 0 1px rgb(46 46 46 / 0.5)',
      'card-hover': '0 0 0 1px rgb(62 207 142 / 0.28)',
      'inner-glow': 'inset 0 1px 0 rgb(255 255 255 / 0.05)'
    },
    borderRadius: {
      none: '0',
      sm: '0.25rem',
      DEFAULT: '0.375rem',
      md: '0.375rem',
      lg: '0.5rem',
      xl: '0.625rem',
      '2xl': '0.75rem',
      '3xl': '1rem',
      '4xl': '1.25rem',
      full: '9999px'
    },
    extend: {
      colors: {
        primary: {
          50: '#ecfdf5',
          100: '#d1fae5',
          200: '#a7f3d0',
          300: '#6ee7b7',
          400: '#3ecf8e',
          500: '#00c573',
          600: '#00a862',
          700: '#008f55',
          800: '#006b45',
          900: '#064e3b',
          950: '#022c22'
        },
        accent: {
          50: '#fafafa',
          100: '#efefef',
          200: '#d7d7d7',
          300: '#b4b4b4',
          400: '#898989',
          500: '#6b6b6b',
          600: '#4d4d4d',
          700: '#393939',
          800: '#2e2e2e',
          900: '#171717',
          950: '#0f0f0f'
        },
        dark: {
          50: '#fafafa',
          100: '#efefef',
          200: '#d7d7d7',
          300: '#b4b4b4',
          400: '#898989',
          500: '#6b6b6b',
          600: '#4d4d4d',
          700: '#393939',
          800: '#2e2e2e',
          900: '#171717',
          950: '#0f0f0f'
        },
        surface: {
          canvas: '#171717',
          raised: '#1d1d1d',
          panel: '#242424',
          overlay: 'rgb(41 41 41 / 0.84)'
        },
        border: {
          subtle: '#242424',
          DEFAULT: '#2e2e2e',
          strong: '#363636',
          accent: 'rgb(62 207 142 / 0.3)'
        },
        radix: {
          slateA2: 'hsl(210 87.8% 16.1% / 0.031)',
          slateA7: 'hsl(200 90.3% 93.4% / 0.109)',
          slateA12: 'hsl(0 0% 100% / 0.93)',
          purple4: 'hsl(280 30% 22%)',
          purple5: 'hsl(279 27.8% 27.6%)',
          purpleA7: 'hsl(280 100% 70% / 0.32)',
          violet10: 'hsl(251 63.2% 63.2%)',
          crimson4: 'hsl(336 42% 21%)',
          crimsonA9: 'hsl(336 80% 57% / 0.78)',
          indigoA2: 'hsl(223 100% 60% / 0.08)',
          yellowA7: 'hsl(46 100% 50% / 0.32)',
          tomatoA4: 'hsl(10 89% 55% / 0.18)',
          orange6: 'hsl(31 74% 31%)'
        }
      },
      fontFamily: {
        sans: [
          'Circular',
          'custom-font',
          'Helvetica Neue',
          'Helvetica',
          'Arial',
          'PingFang SC',
          'Hiragino Sans GB',
          'Microsoft YaHei',
          'sans-serif'
        ],
        mono: [
          'Source Code Pro',
          'Office Code Pro',
          'Menlo',
          'Monaco',
          'Consolas',
          'ui-monospace',
          'monospace'
        ]
      },
      fontSize: {
        hero: ['4.5rem', { lineHeight: '1', fontWeight: '400' }],
        section: ['2.25rem', { lineHeight: '1.25', fontWeight: '400' }],
        card: ['1.5rem', { lineHeight: '1.33', letterSpacing: '-0.01em', fontWeight: '400' }]
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-primary': 'linear-gradient(135deg, #00c573 0%, #3ecf8e 100%)',
        'gradient-dark': 'linear-gradient(180deg, #171717 0%, #0f0f0f 100%)',
        'gradient-glass': 'linear-gradient(180deg, rgb(41 41 41 / 0.84), rgb(23 23 23 / 0.72))',
        'mesh-gradient':
          'linear-gradient(rgb(62 207 142 / 0.035) 1px, transparent 1px), linear-gradient(90deg, rgb(62 207 142 / 0.035) 1px, transparent 1px)'
      },
      animation: {
        'fade-in': 'fadeIn 0.24s ease-out',
        'slide-up': 'slideUp 0.24s ease-out',
        'slide-down': 'slideDown 0.24s ease-out',
        'slide-in-right': 'slideInRight 0.24s ease-out',
        'scale-in': 'scaleIn 0.18s ease-out',
        shimmer: 'shimmer 2s linear infinite',
        glow: 'glow 2s ease-in-out infinite alternate'
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideInRight: {
          '0%': { opacity: '0', transform: 'translateX(16px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' }
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.98)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' }
        },
        glow: {
          '0%': { boxShadow: '0 0 0 1px rgb(62 207 142 / 0.22)' },
          '100%': { boxShadow: '0 0 0 1px rgb(62 207 142 / 0.42)' }
        }
      },
      backdropBlur: {
        xs: '2px'
      }
    }
  },
  plugins: []
}
