"use client"

import { LayoutDashboard, Users, Server, Settings, Globe, Layers, Smartphone, Activity, Copy } from "lucide-react"
import Link from "next/link"
import { usePathname } from "next/navigation"

import { cn } from "@/lib/utils"

const routes = [
  { name: "Dashboard", href: "/", icon: LayoutDashboard },
  { name: "Users", href: "/users", icon: Users },
  { name: "Groups", href: "/groups", icon: Layers },
  { name: "Templates", href: "/templates", icon: Copy },
  { name: "Configs", href: "/configs", icon: Server },
  { name: "Devices", href: "/devices", icon: Smartphone },
  { name: "Nodes", href: "/nodes", icon: Globe },
  { name: "Settings", href: "/settings", icon: Settings },
]

export function Sidebar() {
  const pathname = usePathname()

  return (
    <div className="flex min-h-screen w-64 flex-col border-r bg-zinc-950 text-white">
      <div className="flex h-16 items-center px-6">
        <Activity className="h-6 w-6 text-emerald-500 mr-2" />
        <span className="text-xl font-bold tracking-tight">Horizon</span>
      </div>
      <nav className="flex-1 space-y-1 px-3 py-4">
        {routes.map((route) => {
          const Icon = route.icon
          const isActive = pathname === route.href
          return (
            <Link
              key={route.name}
              href={route.href}
              className={cn(
                "flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors",
                isActive
                  ? "bg-zinc-800 text-white"
                  : "text-zinc-400 hover:bg-zinc-900 hover:text-white"
              )}
            >
              <Icon className="mr-3 h-5 w-5" />
              {route.name}
            </Link>
          )
        })}
      </nav>
      <div className="p-4 border-t border-zinc-900">
        <div className="text-xs text-zinc-500">Aether v2.0.0</div>
      </div>
    </div>
  )
}
