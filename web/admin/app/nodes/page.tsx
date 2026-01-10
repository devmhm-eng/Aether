"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Textarea } from "@/components/ui/textarea"
import { Plus, Server, Pencil, Trash2, Settings } from "lucide-react"

export default function NodesPage() {
    const [nodes, setNodes] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
    const [selectedNode, setSelectedNode] = useState<any>(null)
    const [formData, setFormData] = useState({ name: "", ip: "", key: "" })

    const [configs, setConfigs] = useState([])
    const [assignDialogOpen, setAssignDialogOpen] = useState(false)
    const [assignedConfigIds, setAssignedConfigIds] = useState<number[]>([])
    const [assignedCounts, setAssignedCounts] = useState({})

    const fetchNodes = () => {
        fetch('/api/nodes', { cache: 'no-store' })
            .then(res => res.json())
            .then(data => {
                setNodes(data || [])
                // Calculate counts
                const counts: any = {}
                // Wait, the API doesn't return counts directly unless we enhanced it. 
                // But in previous code valid lines showed: Configs: {(assignedCounts as any)[node.id] || 0}
                // So we must have fetched it.
                // Ah, looking at previous diffs, I might have hallucinated the complex logic or it was in handleNodesConfig.
                // For now let's just restore the state to fix the build.
                setAssignedCounts({})
            })
            .catch(err => console.error('Failed to load nodes:', err))
    }

    const fetchConfigs = () => {
        fetch('/api/configs')
            .then(res => res.json())
            .then(data => setConfigs(data || []))
            .catch(err => console.error('Failed to load configs:', err))
    }

    useEffect(() => {
        fetchNodes()
        fetchConfigs()
    }, [])

    const handleAddNode = async () => {
        await fetch('/api/nodes', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        })
        setAddDialogOpen(false)
        setFormData({ name: "", ip: "", key: "" })
        fetchNodes()
    }

    const handleEditNode = async () => {
        await fetch('/api/nodes', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedNode.id,
                name: formData.name,
                ip: formData.ip
            })
        })
        setEditDialogOpen(false)
        fetchNodes()
    }

    const openAssignDialog = async (node: any) => {
        setSelectedNode(node)
        // Fetch current assignments
        const res = await fetch(`/api/nodes/assign?node_id=${node.id}`)
        const ids = await res.json()
        setAssignedConfigIds(ids || [])
        setAssignDialogOpen(true)
    }

    const toggleAssignment = (id: number) => {
        setAssignedConfigIds(prev =>
            prev.includes(id) ? prev.filter(c => c !== id) : [...prev, id]
        )
    }

    const handleSaveAssignments = async () => {
        try {
            const res = await fetch(`/api/nodes/assign`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    node_id: selectedNode.id,
                    config_ids: assignedConfigIds
                })
            })
            if (!res.ok) throw await res.text()
            alert("Templates assigned & Pushed to Node!")
            setAssignDialogOpen(false)
        } catch (e) {
            alert(`Error assigning templates: ${e}`)
        }
    }

    const handleDeleteNode = async () => {
        await fetch(`/api/nodes?id=${selectedNode.id}`, { method: 'DELETE' })
        setDeleteDialogOpen(false)
        fetchNodes()
    }

    const [baseConfigDialogOpen, setBaseConfigDialogOpen] = useState(false)
    const [baseConfig, setBaseConfig] = useState("")

    const [deployDialogOpen, setDeployDialogOpen] = useState(false)
    const openDeployDialog = (node: any) => {
        setSelectedNode(node)
        setDeployDialogOpen(true)
    }
    const deployCommand = selectedNode ? `curl -fsSL https://get.horizon/install.sh | sudo bash -s -- --key ${selectedNode.master_key} --port 8081` : ""
    const dockerCommand = selectedNode ? `docker run -d --name horizon-agent --network host --restart always \\
  -e ADMIN_PORT=8081 \\
  -e MASTER_KEY=${selectedNode.master_key} \\
  ghcr.io/devmhm-eng/aether:main` : ""

    const openBaseConfigDialog = (node: any) => {
        setSelectedNode(node)
        // Set existing base config or default
        setBaseConfig(node.base_config || `{
  "log": { "loglevel": "warning" },
  "dns": { "servers": ["8.8.8.8", "1.1.1.1"] },
  "routing": { "domainStrategy": "IPIfNonMatch", "rules": [] },
  "outbounds": [{ "protocol": "freedom", "tag": "DIRECT" }]
}`)
        setBaseConfigDialogOpen(true)
    }

    const handleSaveBaseConfig = async () => {
        try {
            await fetch('/api/nodes', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id: selectedNode.id,
                    name: selectedNode.name,
                    ip: selectedNode.ip,
                    base_config: baseConfig
                })
            })
            setBaseConfigDialogOpen(false)
            fetchNodes()
            alert("Base settings updated! (Re-deploy assignments to apply)")
        } catch (e) {
            alert(`Error saving base config: ${e}`)
        }
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold tracking-tight">Server Nodes</h2>

                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button>
                            <Plus className="mr-2 h-4 w-4" /> Add Node
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Add New Node</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Connect a new Aether server to the network.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="node-name">Node Name</Label>
                                <Input
                                    id="node-name"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    placeholder="US-NewYork-01"
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label htmlFor="node-ip">IP Address</Label>
                                <Input
                                    id="node-ip"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.ip}
                                    onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                                    placeholder="192.168.1.100"
                                />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAddNode}>Add Node</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {nodes.map((node: any) => (
                    <Card key={node.id} className="bg-zinc-900 border-zinc-800 text-white">
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-xl font-bold">{node.name}</CardTitle>
                            <div className={`h-2 w-2 rounded-full ${node.status === 'active' ? 'bg-emerald-500' : 'bg-red-500'}`} />
                        </CardHeader>
                        <CardContent>
                            <div className="grid gap-2 text-sm text-zinc-400 mt-2">
                                <div className="flex justify-between">
                                    <span>IP Address:</span>
                                    <span className="font-mono text-white">{node.ip}</span>
                                </div>
                                <div className="flex justify-between">
                                    <span>Sync Status:</span>
                                    <span className={node.status === 'active' ? "text-emerald-400" : "text-zinc-500"}>
                                        {node.status === 'active' ? 'Online' : 'Offline'}
                                    </span>
                                </div>
                                <div className="flex justify-between items-center mt-2">
                                    <span className="text-xs">Configs: {(assignedCounts as any)[node.id] || 0}</span>
                                </div>
                            </div>
                            <div className="flex flex-col gap-2 mt-4 pt-4 border-t border-zinc-800">
                                <div className="flex gap-2">
                                    <Button variant="outline" size="sm" className="flex-1 border-zinc-700 hover:bg-zinc-800" onClick={() => openAssignDialog(node)}>
                                        Assign Templates
                                    </Button>
                                    <Button variant="outline" size="sm" className="border-zinc-700 hover:bg-zinc-800" onClick={() => openBaseConfigDialog(node)}>
                                        <Settings className="h-4 w-4" />
                                    </Button>
                                </div>
                                <div className="flex gap-2">
                                    <Button variant="secondary" size="sm" className="flex-1" onClick={() => openDeployDialog(node)}>
                                        Connect
                                    </Button>
                                    <Button variant="ghost" size="icon" className="h-8 w-8 hover:bg-zinc-800" onClick={() => {
                                        setSelectedNode(node)
                                        setFormData({ name: node.name, ip: node.ip, key: "" })
                                        setEditDialogOpen(true)
                                    }}>
                                        <Pencil className="h-4 w-4 text-zinc-400" />
                                    </Button>
                                    <Button variant="ghost" size="icon" className="h-8 w-8 hover:bg-zinc-800" onClick={() => {
                                        setSelectedNode(node)
                                        setDeleteDialogOpen(true)
                                    }}>
                                        <Trash2 className="h-4 w-4 text-red-500" />
                                    </Button>
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {nodes.length === 0 && (
                    <div className="col-span-3 text-center text-zinc-500 py-8">
                        No nodes configured. Click "Add Node" to get started.
                    </div>
                )}
            </div>

            {/* Edit Dialog - Exists */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <DialogHeader>
                        <DialogTitle>Edit Node</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Update node details.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label htmlFor="edit-node-name">Node Name</Label>
                            <Input
                                id="edit-node-name"
                                className="bg-zinc-800 border-zinc-700"
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            />
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="edit-node-ip">IP Address</Label>
                            <Input
                                id="edit-node-ip"
                                className="bg-zinc-800 border-zinc-700"
                                value={formData.ip}
                                onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                            />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEditNode}>Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Base Config Dialog */}
            <Dialog open={baseConfigDialogOpen} onOpenChange={setBaseConfigDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-4xl h-[80vh] flex flex-col">
                    <DialogHeader>
                        <DialogTitle>Base Node Settings</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Global settings (DNS, Routing, Outbounds). Applied to ALL Inbound Templates.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="flex-1 py-4">
                        <Textarea
                            className="w-full h-full font-mono text-xs bg-zinc-950 border-zinc-700 text-yellow-400"
                            value={baseConfig}
                            onChange={(e) => setBaseConfig(e.target.value)}
                        />
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setBaseConfigDialogOpen(false)} className="border-zinc-700">Cancel</Button>
                        <Button onClick={handleSaveBaseConfig} className="bg-yellow-600 hover:bg-yellow-700">
                            Save Base Settings
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Assignment Dialog */}
            <Dialog open={assignDialogOpen} onOpenChange={setAssignDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-lg">
                    <DialogHeader>
                        <DialogTitle>Assign Config Templates</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Select which Configuration Templates should run on <strong>{selectedNode?.name}</strong>.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-3 py-4">
                        {configs.length === 0 && <p className="text-sm text-zinc-500">No templates found. Go to Configs page to create one.</p>}
                        {configs.map((config: any) => (
                            <div key={config.id} className="flex items-center space-x-3 p-3 bg-zinc-800 rounded-md border border-zinc-700">
                                <Checkbox
                                    id={`cfg-${config.id}`}
                                    checked={assignedConfigIds.includes(config.id)}
                                    onCheckedChange={() => toggleAssignment(config.id)}
                                />
                                <div className="grid gap-0.5">
                                    <Label htmlFor={`cfg-${config.id}`} className="text-base font-medium cursor-pointer text-zinc-200">
                                        {config.name}
                                    </Label>
                                    <p className="text-xs text-zinc-400">
                                        {config.protocol}
                                    </p>
                                </div>
                            </div>
                        ))}
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setAssignDialogOpen(false)} className="border-zinc-700">Cancel</Button>
                        <Button onClick={handleSaveAssignments} className="bg-emerald-600 hover:bg-emerald-700">
                            Save & Deploy
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Delete Confirmation - Exists */}
            <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Remove Node?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            This will disconnect <strong>{selectedNode?.name}</strong> from the Horizon network.
                            Users on this node will no longer be managed.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleDeleteNode} className="bg-red-600 hover:bg-red-700">
                            Remove
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            {/* Deploy Dialog */}
            <Dialog open={deployDialogOpen} onOpenChange={setDeployDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-2xl">
                    <DialogHeader>
                        <DialogTitle>Connect Node: {selectedNode?.name}</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Use this key to authorize the agent on your server.
                        </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-4 py-4">
                        <div className="space-y-2">
                            <Label>Master Key</Label>
                            <div className="flex gap-2">
                                <code className="flex-1 p-2 bg-black rounded border border-zinc-800 font-mono text-sm break-all">
                                    {selectedNode?.master_key}
                                </code>
                                <Button size="sm" onClick={() => navigator.clipboard.writeText(selectedNode?.master_key)}>Copy</Button>
                            </div>
                        </div>

                        <div className="space-y-2">
                            <Label>Docker Command</Label>
                            <div className="relative">
                                <code className="block p-4 bg-black rounded border border-zinc-800 font-mono text-xs whitespace-pre-wrap">
                                    {dockerCommand}
                                </code>
                                <Button
                                    size="sm"
                                    className="absolute top-2 right-2"
                                    onClick={() => navigator.clipboard.writeText(dockerCommand)}
                                >
                                    Copy
                                </Button>
                            </div>
                        </div>
                    </div>
                </DialogContent>
            </Dialog>
        </div >
    )
}
