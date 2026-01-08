"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { TrafficChart } from "@/components/TrafficChart"
import { Activity, Server, Users, Zap } from "lucide-react"

export default function Home() {
  const [stats, setStats] = useState({
    total_users: 0,
    active_nodes: 0,
    total_traffic_gb: 0,
  })

  useEffect(() => {
    fetch('/api/stats')
      .then(res => res.json())
      .then(data => setStats(data))
      .catch(err => console.error('Failed to load stats:', err))
  }, [])

  return (
    <div className="flex-1 space-y-4 p-8 pt-6">
      <div className="flex items-center justify-between space-y-2">
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="bg-zinc-900 border-zinc-800 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Users</CardTitle>
            <Users className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total_users}</div>
            <p className="text-xs text-zinc-500">Registered accounts</p>
          </CardContent>
        </Card>

        <Card className="bg-zinc-900 border-zinc-800 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Nodes</CardTitle>
            <Server className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.active_nodes}</div>
            <p className="text-xs text-zinc-500">Connected servers</p>
          </CardContent>
        </Card>

        <Card className="bg-zinc-900 border-zinc-800 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Traffic</CardTitle>
            <Activity className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total_traffic_gb.toFixed(2)} GB</div>
            <p className="text-xs text-zinc-500">Cumulative usage</p>
          </CardContent>
        </Card>

        <Card className="bg-zinc-900 border-zinc-800 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">System Health</CardTitle>
            <Zap className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">Operational</div>
            <p className="text-xs text-zinc-500">All systems running</p>
          </CardContent>
        </Card>
      </div>

      {/* Charts & Details */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
        <TrafficChart />
        {/* Placeholder for Recent Activity or Server Load */}
        <Card className="col-span-3 bg-zinc-900 border-zinc-800 text-white">
          <CardHeader>
            <CardTitle>Quick Stats</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-zinc-400">Nodes Online</span>
                <span className="font-medium">{stats.active_nodes}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-zinc-400">Total Users</span>
                <span className="font-medium">{stats.total_users}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-zinc-400">Data Transferred</span>
                <span className="font-medium">{stats.total_traffic_gb.toFixed(2)} GB</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
